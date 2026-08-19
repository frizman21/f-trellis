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

  test "the page says what happens to what it finds" do
    get project_source_path(@project, @source)

    assert_match(/recorded in the project and cited to this page/i, response.body)
  end

  test "a completed run shows what it did to the project" do
    run_record(status: "complete", response: '{"entities":[],"relationships":[]}',
               summary: { "entities" => { "created" => 3, "matched" => 1, "skipped" => [] },
                          "relationships" => { "created" => 2, "matched" => 0, "skipped" => [] },
                          "values" => { "created" => 7, "skipped" => [], "conflicts" => [] },
                          "citations" => 11 })

    get project_source_path(@project, @source)

    # Whitespace-tolerant: the counts are rendered across wrapped lines.
    assert_match(/3\s+created,\s+1\s+matched/, response.body)
    assert_match(/11/, response.body)
  end

  # The skips are the useful half: they are where a description needs sharpening.
  test "a run shows what it skipped and why" do
    run_record(status: "complete", response: "{}",
               summary: { "entities" => { "created" => 0, "matched" => 0,
                                          "skipped" => [ { "name" => "Some Agency",
                                                           "reason" => "no entity type named \"Agency\"" } ] },
                          "relationships" => { "created" => 0, "matched" => 0, "skipped" => [] },
                          "values" => { "created" => 0, "skipped" => [], "conflicts" => [] },
                          "citations" => 0 })

    get project_source_path(@project, @source)

    assert_match(/Skipped 1/, response.body)
    assert_match(/Some Agency/, response.body)
    assert_match(/no entity type named/, response.body)
  end

  test "a run shows where it disagreed with a recorded value" do
    run_record(status: "complete", response: "{}",
               summary: { "entities" => { "created" => 0, "matched" => 1, "skipped" => [] },
                          "relationships" => { "created" => 0, "matched" => 0, "skipped" => [] },
                          "values" => { "created" => 0, "skipped" => [],
                                        "conflicts" => [ { "owner" => "Rocketdyne F-1",
                                                           "attribute" => "thrust_kn",
                                                           "stored" => "6770.0",
                                                           "offered" => "6900" } ] },
                          "citations" => 1 })

    get project_source_path(@project, @source)

    assert_match(/Disagreed with 1 recorded value/, response.body)
    assert_match(/kept.*6770\.0/m, response.body)
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

  # --- choosing the model for one run ----------------------------------------
  #
  # The project's default is the preselection, not the only answer: reading one
  # page with a cheaper or a stronger model should not mean changing the
  # project's default and changing it back.

  # Stamped with the setup model's own last_seen_at: `Model.current` keeps only
  # the rows from the most recent refresh, so a later timestamp here would push
  # the project's default out of the registry the page offers.
  def other_model
    @other_model ||= Model.create!(provider: "openai", model_id: "gpt-test",
                                   name: "GPT Test", last_seen_at: @model.last_seen_at)
  end

  test "the page offers a model select preselected to the project default" do
    other_model

    get project_source_path(@project, @source)

    assert_response :success
    assert_select "select[name=?]", "model_id" do
      assert_select "option[value=?][selected]", @model.id.to_s
      assert_select "option[value=?]", other_model.id.to_s
    end
  end

  test "the chosen model is the one the run uses" do
    post extract_project_source_path(@project, @source), params: { model_id: other_model.id }

    assert_equal other_model, ExtractionRun.last.model
    assert_match(/gpt-test/, flash[:notice])
  end

  test "no model chosen falls back to the project default" do
    post extract_project_source_path(@project, @source)

    assert_equal @model, ExtractionRun.last.model
  end

  # Resolved against the registry rather than trusted, so a stale form or a
  # hand-made request cannot bill a model nothing should spend money on.
  test "an unknown or deprecated model falls back to the project default" do
    retired = Model.create!(provider: "anthropic", model_id: "claude-retired",
                            name: "Retired", last_seen_at: @model.last_seen_at, is_deprecated: true)

    post extract_project_source_path(@project, @source), params: { model_id: retired.id }
    assert_equal @model, ExtractionRun.last.model

    post extract_project_source_path(@project, @source), params: { model_id: 0 }
    assert_equal @model, ExtractionRun.last.model
  end

  # --- the conversation behind a run -----------------------------------------

  test "a run that reached the model links to its chat" do
    chat = Chat.create!(model: @model)
    run_record(status: "complete", response: "{}", chat: chat)

    get project_source_path(@project, @source)

    assert_select "a[href=?]", chat_path(chat)
  end

  test "a run that never reached the model shows no chat link" do
    run_record(status: "failed", error: "RubyLLM::Error: upstream said no")

    get project_source_path(@project, @source)

    assert_select "a[href^=?]", "/chats/", count: 0
  end
end
