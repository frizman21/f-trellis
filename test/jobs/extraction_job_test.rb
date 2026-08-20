require "test_helper"
require "zip"

class ExtractionJobTest < ActiveJob::TestCase
  # Captures what the job hands the model without touching the network.
  class FakeChat
    class << self
      attr_accessor :last, :reply, :raise_with
    end

    attr_reader :asked, :instructions, :max_retries

    def initialize(max_retries: nil)
      @max_retries = max_retries
      self.class.last = self
    end

    def with_instructions(content) = @instructions = content

    def ask(text)
      @asked = text
      raise self.class.raise_with if self.class.raise_with

      Struct.new(:content).new(self.class.reply || '{"entities":[],"relationships":[]}')
    end

    def id = 1
  end

  def with_fake_chat
    # Reset before, not after: assertions about what the model was handed run
    # once the block has returned, and clearing in `ensure` would leave them
    # reading nil. It also makes "the job asked nothing" mean something.
    FakeChat.last = nil
    original = Chat.method(:for_model)
    # Keywords, not just positionals: how many retries the job asks for is part
    # of what it hands the model, so the fake has to receive it to be asserted on.
    Chat.define_singleton_method(:for_model) { |*, **options| FakeChat.new(**options) }
    # The job assigns the chat to the run; skip that write for the fake.
    ExtractionRun.class_eval do
      alias_method :update_without_chat_stub!, :update!
      define_method(:update!) do |attrs = {}|
        attrs = attrs.except(:chat) if attrs.is_a?(Hash)
        attrs.empty? ? true : update_without_chat_stub!(attrs)
      end
    end
    yield
  ensure
    Chat.define_singleton_method(:for_model, original)
    ExtractionRun.class_eval do
      remove_method :update!
      alias_method :update!, :update_without_chat_stub!
      remove_method :update_without_chat_stub!
    end
    FakeChat.reply = nil
    FakeChat.raise_with = nil
  end

  setup do
    @project = projects(:apollo)
    @model = Model.create!(provider: "anthropic", model_id: "claude-test",
                           name: "Claude Test", last_seen_at: Time.current)
    @project.update!(default_model: @model)
    @source = sources(:one)
    ProjectSource.create!(project: @project, source: @source)
    store_content("Rocketdyne built the F-1 engine for the Saturn V.")
  end

  # The stored payload is zipped; SourceDatum#text unzips and strips it.
  def store_content(text)
    buffer = Zip::OutputStream.write_buffer do |zip|
      zip.put_next_entry("content")
      zip.write "<html><body><p>#{text}</p></body></html>"
    end
    @source.source_data.create!(data: buffer.string, content_type: "text/html")
  end

  def run_for(project: @project, source: @source)
    ExtractionRun.create!(project: project, source: source, model: @model)
  end

  # Sending the wrong one of these two is the failure that would look like a bad
  # model rather than a bad job, so both are asserted.
  test "hands the model the project's prompt and the page's stripped text" do
    run = run_for

    with_fake_chat { ExtractionJob.perform_now(run) }

    assert_equal ExtractionPrompt.new(@project).to_s, FakeChat.last.instructions
    assert_includes FakeChat.last.asked, "Rocketdyne built the F-1 engine"
    # Stripped: the markup it was stored with must not reach the model.
    assert_not_includes FakeChat.last.asked, "<html>"
  end

  # #62. The default is one call: an endpoint that drops the connection bills for
  # the generation behind each attempt and returns nothing for any of them.
  test "asks for its project's attempt count, one call by default" do
    run = run_for

    with_fake_chat { ExtractionJob.perform_now(run) }

    assert_equal 1, @project.extraction_attempts
    assert_equal 0, FakeChat.last.max_retries
  end

  test "a project that allows more attempts asks for the retries they imply" do
    @project.update!(extraction_attempts: 4)
    run = run_for

    with_fake_chat { ExtractionJob.perform_now(run) }

    assert_equal 3, FakeChat.last.max_retries
  end

  test "a successful run records the reply and completes" do
    run = run_for
    FakeChat.reply = '{"entities":[{"id":"e1","name":"F-1","type":"Rocket Engine"}],"relationships":[]}'

    with_fake_chat { ExtractionJob.perform_now(run) }

    run.reload

    assert_equal "complete", run.status
    assert_includes run.response, "Rocket Engine"
    assert run.completed_at.present?
    assert_equal 1, run.parsed["entities"].size
  end

  # #43 reversed the boundary: the run now consumes its own reply.
  test "a successful run records what the reply describes" do
    run = run_for
    FakeChat.reply = '{"entities":[{"id":"e1","name":"New Thing","type":"Rocket Engine",' \
                     '"attributes":{"thrust_kn":"900.5"}}],"relationships":[]}'

    assert_difference [ -> { Entity.count }, -> { EntityAttributeValue.count },
                        -> { EntityExtractionRun.count } ], 1 do
      with_fake_chat { ExtractionJob.perform_now(run) }
    end

    created = @project.entities.kept.find_by(name: "New Thing")

    assert_equal "Rocket Engine", created.entity_type.name
    assert_in_delta 900.5, created.value_for("thrust_kn")
    # Cited to the page it came from — the reason the join tables exist.
    assert_equal @source, created.entity_extraction_runs.sole.source
  end

  test "the run records a summary of what it did" do
    run = run_for
    FakeChat.reply = '{"entities":[{"id":"e1","name":"New Thing","type":"Rocket Engine"}],' \
                     '"relationships":[]}'

    with_fake_chat { ExtractionJob.perform_now(run) }

    assert_equal 1, run.reload.summary.dig("entities", "created")
  end

  # A reply that cannot be applied is still worth having on the page.
  test "a reply that does not parse still completes and says so" do
    run = run_for
    FakeChat.reply = "Sorry, I could not find anything."

    assert_no_difference -> { Entity.count } do
      with_fake_chat { ExtractionJob.perform_now(run) }
    end

    run.reload

    assert_equal "complete", run.status
    assert_includes run.response, "could not find"
    assert_match(/not valid JSON/i, run.summary["error"])
  end

  test "a provider error fails the run rather than raising" do
    run = run_for
    FakeChat.raise_with = StandardError.new("upstream said no")

    assert_nothing_raised do
      with_fake_chat { ExtractionJob.perform_now(run) }
    end

    run.reload

    assert_equal "failed", run.status
    assert_match(/upstream said no/, run.error)
  end

  # Asking a model an empty question wastes the call and looks like a bad model.
  test "a source with no content fails with a reason and asks nothing" do
    bare = sources(:two)
    ProjectSource.create!(project: @project, source: bare)
    run = run_for(source: bare)

    with_fake_chat { ExtractionJob.perform_now(run) }

    assert_equal "failed", run.reload.status
    assert_match(/no fetched content/, run.error)
    assert_nil FakeChat.last
  end

  test "the run keeps the model it used even if the project's default changes" do
    run = run_for
    with_fake_chat { ExtractionJob.perform_now(run) }

    other = Model.create!(provider: "openai", model_id: "gpt-other", name: "Other",
                          last_seen_at: Time.current)
    @project.update!(default_model: other)

    assert_equal @model, run.reload.model
  end

  test "a run that is not pending is left alone" do
    run = run_for
    run.update!(status: "complete", response: "kept")

    with_fake_chat { ExtractionJob.perform_now(run) }

    assert_equal "kept", run.reload.response
  end
end
