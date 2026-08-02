require "test_helper"
require "zip"

class RunSkillEvaluationJobTest < ActiveJob::TestCase
  Reply = Struct.new(:content)

  # Records what the job hands the model. The chat row itself is real, so the
  # result's FK to it resolves; only the calls that would hit the network are
  # replaced.
  class Recorder
    class << self
      attr_accessor :instructions, :asked, :tools, :reply, :raise_with, :tool_calls, :tool_results
    end

    def self.reset(reply: "Acme Corp, Beta Inc", raise_with: nil, tool_calls: [])
      self.instructions = nil
      self.asked = nil
      self.tools = nil
      self.reply = reply
      self.raise_with = raise_with
      self.tool_calls = tool_calls
      self.tool_results = []
    end
  end

  def with_fake_chat(reply: "Acme Corp, Beta Inc", raise_with: nil, tool_calls: [])
    Recorder.reset(reply: reply, raise_with: raise_with, tool_calls: tool_calls)
    original = Chat.method(:create!)

    Chat.define_singleton_method(:create!) do |*args, **kwargs|
      chat = original.call(*args, **kwargs)
      chat.define_singleton_method(:with_instructions) { |content| Recorder.instructions = content; self }
      chat.define_singleton_method(:with_tools) { |*tools| Recorder.tools = tools; self }
      chat.define_singleton_method(:ask) do |text|
        Recorder.asked = text
        raise Recorder.raise_with if Recorder.raise_with

        # Stands in for a provider deciding to call tools: each entry names a
        # registered tool and the arguments the model would have sent.
        Array(Recorder.tool_calls).each do |tool_name, args|
          tool = Recorder.tools.detect { |t| t.name == tool_name }
          raise "no tool named #{tool_name} was registered" if tool.nil?

          Recorder.tool_results << tool.call(args)
        end

        Reply.new(Recorder.reply)
      end
      chat
    end

    yield
  ensure
    Chat.define_singleton_method(:create!, original)
  end

  setup do
    @skill = Skill.create!(name: "Evaluated skill")
    @revision = @skill.skill_revisions.create!(content: "Pull the orgs.")
    @model = Model.create!(provider: "openai", model_id: "gpt-eval", name: "Eval",
                           last_seen_at: Time.current)
    @source = Source.create!(url: "https://eval.test/page")
    @source.update!(status: "complete")
    attach("<html><body><p>Acme Corp</p><p>Beta Inc</p></body></html>")

    @set = LearningSet.create!(name: "Pages under test")
    @set.add_source(@source)
    @evaluation = SkillEvaluation.create!(name: "Run", skill: @skill, base_model: @model,
                                          learning_set: @set)
    @result = SkillEvaluationResult.create!(skill_evaluation: @evaluation, source: @source,
                                            model: @model, skill_revision: @revision,
                                            status: "pending")
  end

  def attach(html)
    bytes = Zip::OutputStream.write_buffer do |zos|
      zos.put_next_entry("page.html")
      zos.write(html)
    end
    bytes.rewind
    SourceDatum.create!(source: @source, content_type: "application/zip", data: bytes.read)
  end

  test "stores the reply and marks the result complete" do
    with_fake_chat(reply: "Acme Corp, Beta Inc") { RunSkillEvaluationJob.perform_now(@result) }

    @result.reload
    assert_equal "complete", @result.status
    assert_equal "Acme Corp, Beta Inc", @result.response
    assert_nil @result.error
    assert @result.completed_at.present?
    assert @result.duration_seconds >= 0
  end

  test "sends the skill revision as instructions and the page text as the message" do
    with_fake_chat { RunSkillEvaluationJob.perform_now(@result) }

    assert_equal "Pull the orgs.", Recorder.instructions
    assert_includes Recorder.asked, "Acme Corp"
    assert_not_includes Recorder.asked, "<html>", "the model gets text, not markup"
  end

  # The invariant that matters, now tested *with* tools registered: the model is
  # handed recording stand-ins, and an evaluation still writes nothing.
  test "registers the recording stand-ins and creates no entities" do
    assert_no_difference [ "Person.count", "Organization.count", "PersonDetail.count",
                           "OrganizationDetail.count", "PersonOrganization.count",
                           "OrganizationOrganization.count", "PersonOrganizationDetail.count",
                           "OrganizationOrganizationDetail.count" ] do
      with_fake_chat { RunSkillEvaluationJob.perform_now(@result) }
    end

    assert_equal [ RecordingUpsertPersonTool, RecordingUpsertOrganizationTool,
                   RecordingLinkPersonOrganizationTool, RecordingLinkOrganizationOrganizationTool ],
                 Recorder.tools.map(&:class)
  end

  # The stand-ins announce themselves under the writing tools' names, so a model
  # that has learned to call `upsert_organization` still can.
  test "the stand-ins present the writing tools' names, descriptions and schemas" do
    [ [ RecordingUpsertPersonTool, UpsertPersonTool ],
      [ RecordingUpsertOrganizationTool, UpsertOrganizationTool ],
      [ RecordingLinkPersonOrganizationTool, LinkPersonOrganizationTool ],
      [ RecordingLinkOrganizationOrganizationTool, LinkOrganizationOrganizationTool ] ].each do |recording, writing|
      stand_in = recording.new(ProposalRecorder.new)
      real = writing.new(nil)

      assert_equal real.name, stand_in.name
      assert_equal real.description, stand_in.description
      assert_equal real.params_schema, stand_in.params_schema
    end
  end

  test "links the chat the run went through" do
    with_fake_chat { RunSkillEvaluationJob.perform_now(@result) }

    assert @result.reload.chat.present?
    assert_equal @model, @result.chat.model
  end

  test "a failed call is recorded on the result and does not take the run down" do
    with_fake_chat(raise_with: RuntimeError.new("provider down")) do
      RunSkillEvaluationJob.perform_now(@result)
    end

    @result.reload
    assert_equal "failed", @result.status
    assert_match(/provider down/, @result.error)
    assert @result.completed_at.present?
  end

  test "a source with no fetched data fails the result rather than sending nothing" do
    empty = Source.create!(url: "https://eval.test/empty")
    result = SkillEvaluationResult.create!(skill_evaluation: @evaluation, source: empty,
                                           model: @model, skill_revision: @revision,
                                           status: "pending")

    with_fake_chat { RunSkillEvaluationJob.perform_now(result) }

    assert_equal "failed", result.reload.status
    assert_match(/no fetched data/, result.error)
    assert_nil Recorder.asked
  end

  test "a result that is not pending is left alone" do
    @result.update!(status: "complete", response: "Kept.")

    with_fake_chat { RunSkillEvaluationJob.perform_now(@result) }

    assert_equal "Kept.", @result.reload.response
    assert_nil Recorder.asked
  end

  # --- What the run would contribute --------------------------------------

  UPSERT_ORGS = [ "upsert_organization",
                  { organizations: [ { name: "Acme Corp", acronym: "ACME" }, { name: "Beta Inc" } ] } ].freeze

  test "a run stores what it proposed and scores it" do
    with_fake_chat(tool_calls: [ UPSERT_ORGS ]) { RunSkillEvaluationJob.perform_now(@result) }

    @result.reload
    assert_equal "complete", @result.status
    assert_equal 2, @result.score
    assert_equal 2, @result.proposals.size
    assert_includes @result.proposals.map { |p| p["name"] }, "acme corp"
    assert @result.proposal_digest.present?
  end

  # The model gets back what the writing tool would have returned, so the ids it
  # then passes to a link tool resolve.
  test "the ids handed back by an upsert tool are usable by a link tool" do
    PersonOrganizationType.find_or_create_by!(name: "Employment")

    calls = [
      [ "upsert_person", { people: [ { first_name: "Jane", last_name: "Doe" } ] } ],
      [ "upsert_organization", { organizations: [ { name: "Acme Corp" } ] } ],
      [ "link_person_organization", { person_id: 1, organization_id: 1, type: "Employment" } ]
    ]

    assert_no_difference [ "Person.count", "Organization.count", "PersonOrganization.count" ] do
      with_fake_chat(tool_calls: calls) { RunSkillEvaluationJob.perform_now(@result) }
    end

    assert_nil Recorder.tool_results.last[:error]
    link = @result.reload.proposals.detect { |p| p["type"] == "person_organization" }
    assert_equal "jane doe", link["person"]
    assert_equal 3, @result.score
  end

  test "the same organization proposed twice scores once" do
    duplicate = [ "upsert_organization", { organizations: [ { name: "Acme Corp" }, { name: "acme corp" } ] } ]

    with_fake_chat(tool_calls: [ duplicate ]) { RunSkillEvaluationJob.perform_now(@result) }

    assert_equal 1, @result.reload.score
  end

  test "a run that proposed nothing scores zero, not nil" do
    with_fake_chat { RunSkillEvaluationJob.perform_now(@result) }

    assert_equal 0, @result.reload.score
    assert_empty @result.proposals
  end

  test "two runs proposing the same set in a different order share a digest" do
    other_model = Model.create!(provider: "openai", model_id: "gpt-other", name: "Other",
                                last_seen_at: @model.last_seen_at)
    other = SkillEvaluationResult.create!(skill_evaluation: @evaluation, source: @source,
                                          model: other_model, skill_revision: @revision,
                                          status: "pending")

    with_fake_chat(tool_calls: [ UPSERT_ORGS ]) { RunSkillEvaluationJob.perform_now(@result) }
    reversed = [ "upsert_organization",
                 { organizations: [ { name: "Beta Inc" }, { name: "Acme Corp", acronym: "ACME" } ] } ]
    with_fake_chat(tool_calls: [ reversed ]) { RunSkillEvaluationJob.perform_now(other) }

    assert @result.reload.same_proposals_as?(other.reload)
  end
end
