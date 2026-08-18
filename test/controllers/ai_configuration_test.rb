require "test_helper"

class AiConfigurationTest < ActionDispatch::IntegrationTest
  setup { @project = projects(:apollo) }

  test "the project page links to it" do
    get project_path(@project)

    assert_select "a[href=?]", ai_configuration_project_path(@project), text: "AI Configuration"
  end

  test "the page renders the generated prompt" do
    get ai_configuration_project_path(@project)

    assert_response :success
    assert_select "h1", "AI Configuration"
    assert_match(/Rocket Engine/, response.body)
    assert_match(/thrust_kn/, response.body)
  end

  test "a project with no types says so rather than showing an empty schema" do
    Relationship.where(project: projects(:gemini)).destroy_all
    projects(:gemini).relationship_types.destroy_all
    projects(:gemini).entities.destroy_all
    projects(:gemini).entity_types.destroy_all

    get ai_configuration_project_path(projects(:gemini))

    assert_response :success
    assert_match(/defines no entity or relationship types yet/, response.body)
  end

  test "it 404s for a project that does not exist" do
    get ai_configuration_project_path(id: 0)

    assert_response :not_found
  end
end
