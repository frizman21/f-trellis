require "test_helper"
require "zip"

class ExtractionTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:apollo)
    @model = Model.create!(provider: "anthropic", model_id: "claude-test",
                           name: "Claude Test", last_seen_at: Time.current)
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

  def run_record(**attrs)
    ExtractionRun.create!({ project: @project, source: @source, model: @model }.merge(attrs))
  end

  # --- the button ------------------------------------------------------------

  test "extracting enqueues one job and redirects" do
    assert_difference -> { ExtractionRun.count }, 1 do
      assert_enqueued_with(job: ExtractionJob) do
        post extract_project_source_path(@project, @source)
      end
    end

    assert_redirected_to project_source_path(@project, @source)
    assert_equal "pending", ExtractionRun.last.status
    assert_equal @model, ExtractionRun.last.model
  end

  test "the page offers the button when everything is ready" do
    get project_source_path(@project, @source)

    assert_response :success
    assert_select "form[action=?]", extract_project_source_path(@project, @source)
    assert_select "button[disabled]", count: 0
  end

  # Disabled with the reason rather than enabled and failing.
  test "no default model disables the button and says so" do
    @project.update!(default_model: nil)

    get project_source_path(@project, @source)

    assert_select "button[disabled]"
    assert_match(/no default model/i, response.body)
  end

  test "no fetched content disables the button and says so" do
    @source.source_data.destroy_all

    get project_source_path(@project, @source)

    assert_select "button[disabled]"
    assert_match(/no fetched content/i, response.body)
  end

  test "an empty structure disables the button and says so" do
    Relationship.where(project: @project).destroy_all
    @project.relationship_types.destroy_all
    @project.entities.destroy_all
    @project.entity_types.destroy_all

    get project_source_path(@project, @source)

    assert_select "button[disabled]"
    assert_match(/defines nothing to extract/i, response.body)
  end

  # A double click should not be two API calls.
  test "a run already in flight disables the button" do
    run_record(status: "running")

    get project_source_path(@project, @source)

    assert_select "button[disabled]"
    assert_match(/already running/i, response.body)
  end

  # The check lives in one place, so a hand-made request cannot skip it.
  test "posting while one is in flight enqueues nothing" do
    run_record(status: "pending")

    assert_no_difference -> { ExtractionRun.count } do
      post extract_project_source_path(@project, @source)
    end

    assert flash[:alert].present?
  end

  test "posting with no default model enqueues nothing" do
    @project.update!(default_model: nil)

    assert_no_difference -> { ExtractionRun.count } do
      post extract_project_source_path(@project, @source)
    end

    assert flash[:alert].present?
  end

  # --- showing the result ----------------------------------------------------

  test "a completed run shows its JSON, pretty-printed" do
    run_record(status: "complete", response: '{"entities":[],"relationships":[]}')

    get project_source_path(@project, @source)

    assert_response :success
    rendered = css_select("pre").map(&:text).join
    assert_includes rendered, %("entities": [])
  end

  # A model wrapping its answer in prose is ordinary, not an error.
  test "a reply that is not JSON is shown raw and marked" do
    run_record(status: "complete", response: "Here you go: not actually json")

    get project_source_path(@project, @source)

    assert_match(/not valid JSON/i, response.body)
    assert_includes css_select("pre").map(&:text).join, "not actually json"
  end

  # The single most common way an otherwise perfect reply fails to parse.
  test "a fenced JSON reply still parses" do
    run = run_record(status: "complete", response: "```json\n{\"entities\":[]}\n```")

    assert run.parsed?
    assert_equal [], run.parsed["entities"]
  end

  test "a failed run shows its error" do
    run_record(status: "failed", error: "RubyLLM::Error: upstream said no")

    get project_source_path(@project, @source)

    assert_match(/upstream said no/, response.body)
  end

  test "the page says nothing is written to the project's data" do
    get project_source_path(@project, @source)

    assert_match(/Nothing is written to the project's data/i, response.body)
  end

  # Another project reading the same page has its own runs, behind its own
  # structure.
  test "runs are scoped to the project" do
    other = projects(:gemini)
    ProjectSource.create!(project: other, source: @source)
    ExtractionRun.create!(project: other, source: @source, model: @model,
                          status: "complete", response: '{"other":"project"}')

    get project_source_path(@project, @source)

    assert_no_match(/other.*project/, css_select("pre").map(&:text).join)
  end

  # --- the project's model ---------------------------------------------------

  test "the project form offers selectable models and saves the choice" do
    get edit_project_path(@project)

    assert_select "select[name=?] option[value=?]", "project[default_model_id]", @model.id.to_s

    patch project_path(@project), params: { project: { name: @project.name, default_model_id: @model.id } }

    assert_equal @model, @project.reload.default_model
  end

  test "a project with no default model still saves" do
    patch project_path(@project), params: { project: { name: "Renamed", default_model_id: "" } }

    assert_equal "Renamed", @project.reload.name
    assert_nil @project.default_model
  end
end
