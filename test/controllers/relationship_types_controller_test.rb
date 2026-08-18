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
           params: { relationship_type: { name: "Feeds", description: "Replaces it.",
                                          from_entity_type_id: entity_types(:rocket_engine).id,
                                          to_entity_type_id: entity_types(:launch_vehicle).id } }
    end

    assert_equal @project, RelationshipType.find_by(name: "Feeds").project
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

  # --- the two ends ----------------------------------------------------------

  test "create without both ends makes nothing" do
    assert_no_difference -> { RelationshipType.count } do
      post project_relationship_types_path(@project),
           params: { relationship_type: { name: "Endless" } }
    end

    assert_response :unprocessable_entity
  end

  test "the form offers only this project's entity types at each end" do
    get new_project_relationship_type_path(@project)

    [ "relationship_type[from_entity_type_id]", "relationship_type[to_entity_type_id]" ].each do |field|
      assert_select "select[name=?] option", field do |options|
        offered = options.map { |o| o["value"] }.compact_blank.map(&:to_i)

        assert_equal @project.entity_types.pluck(:id).sort, offered.sort
        assert_not_includes offered, entity_types(:gemini_capsule).id
      end
    end
  end

  test "index states the shape of each type" do
    get project_relationship_types_path(@project)

    assert_select "td", text: "Rocket Engine → Launch Vehicle"
  end

  test "show states the shape" do
    get project_relationship_type_path(@project, relationship_types(:powers))

    assert_select ".badge", text: "Rocket Engine → Launch Vehicle"
  end
end
