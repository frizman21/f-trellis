require "test_helper"
require "zip"

class ProcessReportJobTest < ActiveJob::TestCase
  # Captures what the job hands the model without touching the network.
  class FakeChat
    class << self
      attr_accessor :last
    end

    attr_reader :asked, :instructions, :tools

    def initialize
      self.class.last = self
    end

    def with_instructions(content)
      @instructions = content
    end

    def with_tools(*tools)
      @tools = tools
    end

    def ask(text)
      @asked = text
    end

    def id
      1
    end
  end

  def with_fake_chat(chat_class = FakeChat)
    original = Chat.method(:create!)
    Chat.define_singleton_method(:create!) { |*, **| chat_class.new }
    # The job assigns the chat to the report; skip that write for the fake.
    SourceProcessingReport.class_eval do
      alias_method :update_without_chat_stub!, :update!
      define_method(:update!) do |attrs = {}|
        attrs = attrs.except(:chat) if attrs.is_a?(Hash)
        attrs.empty? ? true : update_without_chat_stub!(attrs)
      end
    end
    yield
  ensure
    Chat.define_singleton_method(:create!, original)
    SourceProcessingReport.class_eval do
      remove_method :update!
      alias_method :update!, :update_without_chat_stub!
      remove_method :update_without_chat_stub!
    end
  end

  def report_for(html)
    source = Source.create!(url: "https://process.test/page")
    source.update!(status: "complete")

    bytes = Zip::OutputStream.write_buffer do |zos|
      zos.put_next_entry("page.html")
      zos.write(html)
    end
    bytes.rewind
    SourceDatum.create!(source: source, content_type: "application/zip", data: bytes.read)

    skill = Skill.create!(name: "Test skill")
    revision = skill.skill_revisions.create!(content: "Do the thing.")

    SourceProcessingReport.create!(source: source, skill_revision: revision,
                                   status: "new", facts: [])
  end

  test "sends the page text to the model, not the raw html" do
    report = report_for(<<~HTML)
      <html>
        <head><style>.a { color: red }</style></head>
        <body><script>tracker()</script><h1>Exhibitor list</h1><p>Acme Corp</p></body>
      </html>
    HTML

    with_fake_chat { ProcessReportJob.perform_now(report) }

    asked = ProcessReportJobTest::FakeChat.last.asked

    assert_includes asked, "Exhibitor list"
    assert_includes asked, "Acme Corp"
    assert_not_includes asked, "<html"
    assert_not_includes asked, "<script"
    assert_not_includes asked, "tracker()"
    assert_not_includes asked, "color: red"
  end

  test "passes the skill revision content as instructions" do
    report = report_for("<html><body><p>content</p></body></html>")

    with_fake_chat { ProcessReportJob.perform_now(report) }

    assert_equal "Do the thing.", ProcessReportJobTest::FakeChat.last.instructions
  end

  test "marks the report complete" do
    report = report_for("<html><body><p>content</p></body></html>")

    with_fake_chat { ProcessReportJob.perform_now(report) }

    assert_equal "complete", report.reload.status
  end

  # A tool the run does not register is a tool the skill cannot use, however
  # well the skill is written.
  test "registers the writing tools, including the part-to-organization link" do
    report = report_for("<html><body><p>content</p></body></html>")

    with_fake_chat { ProcessReportJob.perform_now(report) }

    names = ProcessReportJobTest::FakeChat.last.tools.map(&:name)

    assert_includes names, "link_part_organization"
    assert_equal %w[create_person_organization_type create_person_person_type
                    link_organization_organization link_part_organization
                    link_person_organization link_person_person
                    upsert_organization upsert_part upsert_person], names.sort
  end

  test "fails the report when the page has no extractable text" do
    report = report_for("<html><head><title>t</title></head></html>")

    assert_raises ProcessReportJob::ReportNotProcessable do
      with_fake_chat { ProcessReportJob.perform_now(report) }
    end

    report.reload

    assert_equal "failed", report.status
    # The reason has to survive the job: reports have no show page, so a message
    # that lives only in the log cannot be read from the application at all.
    assert_equal "ProcessReportJob::ReportNotProcessable: source has no fetched data",
                 report.error
  end

  test "records the class and message of an error raised mid-run" do
    report = report_for("<html><body><p>content</p></body></html>")

    raising = Class.new(FakeChat) do
      def ask(_text) = raise IOError, "provider hung up"
    end

    assert_raises IOError do
      with_fake_chat(raising) { ProcessReportJob.perform_now(report) }
    end

    report.reload

    assert_equal "failed", report.status
    assert_equal "IOError: provider hung up", report.error
  end

  test "a completed run records no error" do
    report = report_for("<html><body><p>content</p></body></html>")

    with_fake_chat { ProcessReportJob.perform_now(report) }

    assert_equal "complete", report.reload.status
    assert_nil report.error
  end
end
