require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  test "index renders and lists every project" do
    get projects_path

    assert_response :success
    assert_select "h1", "Projects"
    assert_select "td", text: "Apollo Program"
    assert_select "td", text: "Gemini Program"
  end

  test "index shows the empty state when there are no projects" do
    # destroy_all, not delete_all: a project now owns an ontology and its data,
    # and deleting the row out from under them violates the foreign keys.
    Project.destroy_all

    get projects_path

    assert_response :success
    assert_match(/No projects yet/, response.body)
  end

  test "index links each project to its edit page" do
    get projects_path

    assert_select "a[href=?]", edit_project_path(projects(:apollo)), text: "Edit"
  end

  # --- the root and the sidebar ----------------------------------------------

  test "the root is the projects list" do
    get root_path

    assert_response :success
    assert_select "h1", "Projects"
  end

  test "the projects list renders no sidebar, signed in" do
    get projects_path

    assert_response :success
    assert_select "nav.sidebar", count: 0
    # Full width rather than the sidebar-offset column, or the page would render
    # in a nine-column gutter with nothing beside it.
    assert_select "main.col-12"
    assert_select "main.col-md-9", count: 0
  end

  # The list was only reachable from the breadcrumb, which is absent outside a
  # project — so from Sources or Models there was no way back to it but the
  # browser's own history.
  test "the sidebar links back to the projects list" do
    get sources_path

    assert_response :success
    assert_select "nav.sidebar h6", text: "Research"
    assert_select "nav.sidebar a[href=?]", projects_path, text: "Projects"
  end

  test "suppressing the sidebar does not leak to other pages" do
    get domains_path

    assert_response :success
    assert_select "nav.sidebar"
    assert_select "main.col-md-9"
  end

  # --- create ----------------------------------------------------------------

  test "new renders the form" do
    get new_project_path

    assert_response :success
    assert_select "form input[name=?]", "project[name]"
  end

  test "create makes a project and redirects to the list" do
    assert_difference -> { Project.count }, 1 do
      post projects_path, params: { project: { name: "Artemis Program" } }
    end

    assert_redirected_to projects_path
    assert_equal "Project \"Artemis Program\" created.", flash[:notice]
  end

  test "create rejects a blank name" do
    assert_no_difference -> { Project.count } do
      post projects_path, params: { project: { name: "" } }
    end

    assert_response :unprocessable_entity
    assert_select "div.alert-danger"
  end

  # --- update ----------------------------------------------------------------

  test "update renames a project" do
    patch project_path(projects(:apollo)), params: { project: { name: "Apollo Applications" } }

    assert_redirected_to projects_path
    assert_equal "Apollo Applications", projects(:apollo).reload.name
  end

  test "the form offers the attempt count with the project's current value" do
    projects(:apollo).update!(extraction_attempts: 3)

    get edit_project_path(projects(:apollo))

    assert_response :success
    assert_select "input[name=?][value=?]", "project[extraction_attempts]", "3"
  end

  # #62. The form is the only place the number can be changed, so an unpermitted
  # parameter here would look like a setting that silently refuses to move.
  test "update changes how many times an extraction is attempted" do
    patch project_path(projects(:apollo)), params: { project: { extraction_attempts: 4 } }

    assert_equal 4, projects(:apollo).reload.extraction_attempts
  end

  test "update rejects an attempt count outside the allowed range" do
    patch project_path(projects(:apollo)), params: { project: { extraction_attempts: 0 } }

    assert_response :unprocessable_entity
    assert_equal 1, projects(:apollo).reload.extraction_attempts
  end

  test "update rejects a blank name" do
    patch project_path(projects(:apollo)), params: { project: { name: "" } }

    assert_response :unprocessable_entity
    assert_equal "Apollo Program", projects(:apollo).reload.name
  end

  # --- the two sides ---------------------------------------------------------

  test "the listing links each project to both of its sides" do
    get projects_path

    assert_select "a[href=?]", structure_project_path(projects(:apollo))
    assert_select "a[href=?]", project_path(projects(:apollo))
    assert_select "a[href=?]", structure_project_path(projects(:gemini))
    assert_select "a[href=?]", project_path(projects(:gemini))
  end

  test "the listing counts what each project holds on each side" do
    get projects_path

    assert_select "a[href=?]", structure_project_path(projects(:apollo)),
                  text: /Structure\s+#{projects(:apollo).entity_types.count}/
    assert_select "a[href=?]", project_path(projects(:gemini)),
                  text: /Data\s+#{projects(:gemini).entities.count}/
  end

  # With everything scoped, an ontology screen with no project has nothing to
  # show, so the top-level routes are gone rather than left resolving.
  test "the top-level ontology routes no longer resolve" do
    get "/entities"
    assert_response :not_found

    get "/entity_types"
    assert_response :not_found
  end
end
