require "test_helper"

class RelationshipTypesControllerTest < ActionDispatch::IntegrationTest
  setup { @project = projects(:apollo) }

  test "index renders and lists this project's relationship types" do
    get project_relationship_types_path(@project)

    assert_response :success
    assert_select "h1", "Relationship Types"
    assert_select "a", text: "Powers"
  end

  test "index shows only this project's types" do
    get project_relationship_types_path(@project)

    assert_select "a", text: "Docks With", count: 0
    assert_select "tbody tr", @project.relationship_types.count
  end

  test "another project's type is not found under this project" do
    get project_relationship_type_path(@project, relationship_types(:gemini_docks))

    assert_response :not_found
  end

  test "show lists the type's attributes and their value types" do
    get project_relationship_type_path(@project, relationship_types(:powers))

    assert_response :success
    assert_select "td", text: "engine_count"
    assert_select "td", text: "int"
  end

  test "create makes a type in this project" do
    assert_difference -> { RelationshipType.count }, 1 do
      post project_relationship_types_path(@project),
           params: { relationship_type: { name: "Supersedes", description: "Replaces it." } }
    end

    assert_equal @project, RelationshipType.find_by(name: "Supersedes").project
  end

  test "create rejects a name already used in this project" do
    assert_no_difference -> { RelationshipType.count } do
      post project_relationship_types_path(@project), params: { relationship_type: { name: "Powers" } }
    end

    assert_response :unprocessable_entity
  end

  test "update renames a type" do
    type = relationship_types(:bare_relation)

    patch project_relationship_type_path(@project, type),
          params: { relationship_type: { name: "Renamed" } }

    assert_equal "Renamed", type.reload.name
  end

  test "destroy removes an unused type" do
    assert_difference -> { RelationshipType.count }, -1 do
      delete project_relationship_type_path(@project, relationship_types(:bare_relation))
    end
  end

  # Edges of a kind mean nothing once the kind is gone.
  test "destroy is refused while relationships still use the type" do
    assert_no_difference -> { RelationshipType.count } do
      delete project_relationship_type_path(@project, relationship_types(:powers))
    end

    assert flash[:alert].present?
  end

  test "the ontology header offers both halves, with this one active" do
    get project_relationship_types_path(@project)

    assert_select "a.nav-link.active[href=?]", project_relationship_types_path(@project)
    assert_select "a.nav-link[href=?]", project_entity_types_path(@project)
  end
end
