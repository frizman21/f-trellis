require "test_helper"

# A chat records the conversation and nothing about why it happened, so a chat
# that never got a reply reads as frozen rather than as failed.
class ChatOwnerDisplayTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:apollo)
    @source = sources(:one)
    @model = Model.create!(provider: "anthropic", model_id: "claude-test", name: "Claude Test",
                           last_seen_at: Time.current)
    @chat = Chat.create!(model: @model)
  end

  test "a chat from a failed extraction names the run and its error" do
    run = ExtractionRun.create!(project: @project, source: @source, model: @model, chat: @chat,
                                status: "failed", started_at: 5.minutes.ago,
                                completed_at: 1.minute.ago,
                                error: "Faraday::ConnectionFailed: end of file reached")

    get chat_path(@chat)

    assert_response :success
    assert_match(/Extraction run ##{run.id}/, response.body)
    assert_match(/failed/, response.body)
    assert_match(/end of file reached/, response.body)
    assert_select "a[href=?]", project_source_path(@project, @source)
  end

  # The row still says `running`; the page says what is true, and says where to
  # correct it.
  test "a chat from a stalled extraction says so rather than repeating the column" do
    ExtractionRun.create!(project: @project, source: @source, model: @model, chat: @chat,
                          status: "running", started_at: (ExtractionRun.stall_after + 1.minute).ago)

    get chat_path(@chat)

    assert_match(/stalled/, response.body)
    assert_match(/worker was most likely restarted/, response.body)
  end

  test "a chat from a live extraction shows the run as running" do
    ExtractionRun.create!(project: @project, source: @source, model: @model, chat: @chat,
                          status: "running", started_at: 1.minute.ago)

    get chat_path(@chat)

    assert_match(/running/, response.body)
    assert_no_match(/worker was most likely restarted/, response.body)
  end

  test "a chat from a processing report names the report" do
    revision = skill_revisions(:promoted_1)
    report = SourceProcessingReport.create!(source: @source, skill_revision: revision,
                                            model: @model, chat: @chat, status: "failed",
                                            facts: [], error: "upstream said no")

    get chat_path(@chat)

    assert_match(/Processing report ##{report.id}/, response.body)
    assert_match(/upstream said no/, response.body)
    assert_select "a[href=?]", source_path(@source)
  end

  # A Try it trial creates no chat at all, and an older row may have lost its
  # owner. Neither is an error.
  test "a chat nothing owns renders without the banner" do
    get chat_path(@chat)

    assert_response :success
    assert_no_match(/Extraction run/, response.body)
    assert_no_match(/Processing report/, response.body)
  end
end
