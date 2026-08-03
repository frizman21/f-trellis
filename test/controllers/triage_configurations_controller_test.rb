require "test_helper"
require "zip"

class TriageConfigurationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @model = Model.create!(provider: "anthropic", model_id: "claude-aaa", name: "claude-aaa",
                           last_seen_at: Time.current)
    @skill = Skill.create!(name: "Pull orgs", applicability: "Directory pages.", is_active: true)
    @skill.skill_revisions.create!(content: "Do it.")
  end

  def fetched_source(url = "https://triage.test/exhibitors")
    source = Source.create!(url: url)
    bytes = Zip::OutputStream.write_buffer do |zos|
      zos.put_next_entry("page.html")
      zos.write("<html><body><p>Acme Corp</p></body></html>")
    end
    bytes.rewind
    SourceDatum.create!(source: source, content_type: "application/zip", data: bytes.read)
    source
  end

  test "show renders before any configuration has been saved, and writes nothing" do
    assert_no_difference "TriageConfiguration.count" do
      get triage_configuration_path
    end

    assert_response :success
  end

  test "show renders the default instructions when none are configured" do
    get triage_configuration_path

    assert_response :success
    assert_select "form"
    assert_match "You route pages to extraction skills", response.body
  end

  test "show renders the example prompt from the most recently fetched source" do
    fetched_source("https://triage.test/old")
    newest = fetched_source("https://triage.test/new")

    get triage_configuration_path

    assert_response :success
    assert_match newest.url, response.body
    assert_match "Acme Corp", response.body
  end

  test "show renders when no source has been fetched" do
    get triage_configuration_path

    assert_response :success
    assert_match SkillTriage::PREVIEW_PLACEHOLDER_EXCERPT, response.body
  end

  test "show renders when no skills are routable" do
    Skill.destroy_all

    get triage_configuration_path

    assert_response :success
    assert_match(/no skills are routable/i, response.body)
  end

  test "show makes no model call" do
    fetched_source

    assert_no_difference "Chat.count" do
      get triage_configuration_path
    end

    assert_response :success
  end

  test "update saves the instructions and the model" do
    patch triage_configuration_path, params: {
      triage_configuration: { instructions: "Route only parts pages.", model_id: @model.id }
    }

    assert_redirected_to triage_configuration_path
    config = TriageConfiguration.current
    assert_equal "Route only parts pages.", config.instructions
    assert_equal @model, config.model
  end

  test "clearing both fields restores the defaults" do
    TriageConfiguration.create!(instructions: "Something", model: @model)

    patch triage_configuration_path, params: {
      triage_configuration: { instructions: "", model_id: "" }
    }

    config = TriageConfiguration.current.reload
    assert_nil config.instructions
    assert_nil config.model
    assert_equal TriageConfiguration::DEFAULT_INSTRUCTIONS, config.effective_instructions
    assert_equal @model, config.effective_model
  end

  test "update does not create a second configuration" do
    get triage_configuration_path
    patch triage_configuration_path, params: { triage_configuration: { instructions: "Once." } }

    assert_equal 1, TriageConfiguration.count
  end
end
