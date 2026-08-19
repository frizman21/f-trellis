require "test_helper"
require "zip"

# A run whose worker died must not take a page out of service, and must be
# correctable from the page it appears on.
class StalledRunTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:apollo)
    @model = Model.create!(provider: "anthropic", model_id: "claude-test", name: "Claude Test",
                           last_seen_at: Time.current)
    @project.update!(default_model: @model)
    @source = sources(:one)
    ProjectSource.create!(project: @project, source: @source)
    store_content
  end

  def store_content
    buffer = Zip::OutputStream.write_buffer do |zip|
      zip.put_next_entry("content")
      zip.write "<html><body><p>Some page text about engines.</p></body></html>"
    end
    @source.source_data.create!(data: buffer.string, content_type: "text/html")
  end

  def run_record(started_at:, project: @project, source: @source)
    ExtractionRun.create!(project: project, source: source, model: @model,
                          status: "running", started_at: started_at)
  end

  def stale_started_at = (ExtractionRun.stall_after + 1.minute).ago

  # --- the button comes back on its own --------------------------------------

  # One killed worker took the page out of service indefinitely, with nothing in
  # the UI able to clear it.
  test "a stalled run stops blocking extraction, with no click" do
    run_record(started_at: stale_started_at)

    get project_source_path(@project, @source)

    assert_response :success
    assert_select "button[disabled]", count: 0
    assert_no_match(/already running/i, response.body)
  end

  test "a live run still blocks extraction" do
    run_record(started_at: 2.minutes.ago)

    get project_source_path(@project, @source)

    assert_select "button[disabled]"
    assert_match(/already running/i, response.body)
  end

  # The check lives in one place, so posting cannot skip it either.
  test "posting while a live run is in flight is still refused" do
    run_record(started_at: 2.minutes.ago)

    assert_no_difference -> { ExtractionRun.count } do
      post extract_project_source_path(@project, @source)
    end

    assert flash[:alert].present?
  end

  test "posting while only a stalled run exists is allowed" do
    run_record(started_at: stale_started_at)

    assert_difference -> { ExtractionRun.count }, 1 do
      post extract_project_source_path(@project, @source)
    end
  end

  # --- what the card says ----------------------------------------------------

  test "a live run shows how long it has been going and when it gives up" do
    run_record(started_at: 4.minutes.ago)

    get project_source_path(@project, @source)

    assert_match(/Waiting for the model/, response.body)
    assert_match(/4 minutes elapsed/, response.body)
    assert_match(/Gives up after #{(ExtractionRun.gives_up_after / 60).round} minutes/, response.body)
  end

  # The row still says `running`; the badge says what is true.
  test "a stalled run is badged stalled and offers to be cleared" do
    run = run_record(started_at: stale_started_at)

    get project_source_path(@project, @source)

    assert_match(/stalled/, response.body)
    assert_match(/worker was most likely restarted/, response.body)
    assert_select "form[action=?]", abandon_project_extraction_run_path(@project, run)
  end

  # --- clearing it -----------------------------------------------------------

  test "marking a stalled run failed records why" do
    run = run_record(started_at: stale_started_at)

    post abandon_project_extraction_run_path(@project, run)

    run.reload

    assert_equal "failed", run.status
    assert_not_nil run.completed_at
    assert_match(/Abandoned after \d+ minutes/, run.error)
    assert_redirected_to project_source_path(@project, @source)
  end

  # A live job finishes and calls run.update! minutes later, which would
  # overwrite this and leave the screen and the database disagreeing.
  test "a live run refuses to be abandoned" do
    run = run_record(started_at: 2.minutes.ago)

    post abandon_project_extraction_run_path(@project, run)

    assert_equal "running", run.reload.status
    assert_match(/still within the time/i, flash[:alert])
  end

  test "a run belonging to another project is not found" do
    other = projects(:gemini)
    ProjectSource.create!(project: other, source: @source)
    run = run_record(started_at: stale_started_at, project: other)

    post abandon_project_extraction_run_path(@project, run)

    assert_response :not_found
    assert_equal "running", run.reload.status
  end

  test "a read-only account cannot abandon a run" do
    run = run_record(started_at: stale_started_at)
    sign_in User.create!(email: "reader-abandon@example.com", password: "password", read_only: true)

    post abandon_project_extraction_run_path(@project, run)

    assert_response :forbidden
    assert_equal "running", run.reload.status
  end
end
