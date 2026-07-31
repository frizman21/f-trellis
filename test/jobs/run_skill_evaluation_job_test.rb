require "test_helper"
require "zip"

class RunSkillEvaluationJobTest < ActiveJob::TestCase
  Reply = Struct.new(:content)

  # Records what the job hands the model. The chat row itself is real, so the
  # result's FK to it resolves; only the calls that would hit the network are
  # replaced.
  class Recorder
    class << self
      attr_accessor :instructions, :asked, :tools, :reply, :raise_with
    end

    def self.reset(reply: "Acme Corp, Beta Inc", raise_with: nil)
      self.instructions = nil
      self.asked = nil
      self.tools = nil
      self.reply = reply
      self.raise_with = raise_with
    end
  end

  def with_fake_chat(reply: "Acme Corp, Beta Inc", raise_with: nil)
    Recorder.reset(reply: reply, raise_with: raise_with)
    original = Chat.method(:create!)

    Chat.define_singleton_method(:create!) do |*args, **kwargs|
      chat = original.call(*args, **kwargs)
      chat.define_singleton_method(:with_instructions) { |content| Recorder.instructions = content; self }
      chat.define_singleton_method(:with_tools) { |*tools| Recorder.tools = tools; self }
      chat.define_singleton_method(:ask) do |text|
        Recorder.asked = text
        raise Recorder.raise_with if Recorder.raise_with

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

  # An evaluation is a rehearsal. Handing it the upsert tools would let a
  # rehearsal write into the graph it is supposed to be measuring.
  test "registers no tools and creates no entities" do
    assert_no_difference [ "Person.count", "Organization.count", "PersonDetail.count",
                           "OrganizationDetail.count" ] do
      with_fake_chat { RunSkillEvaluationJob.perform_now(@result) }
    end

    assert_nil Recorder.tools
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
end
