require "test_helper"

class RelationshipTypesControllerTest < ActionDispatch::IntegrationTest
  setup { @project = projects(:apollo) }



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

  # Soft since #66: the row stays and the type leaves the ontology.
  test "destroy removes an unused type" do
    type = relationship_types(:bare_relation)

    assert_difference -> { RelationshipType.kept.count }, -1 do
      assert_no_difference -> { RelationshipType.count } do
        delete project_relationship_type_path(@project, type)
      end
    end

    assert type.reload.discarded?
  end

  # Edges of a kind mean nothing once the kind is gone, so they go with it.
  test "destroy takes the relationships of that kind with it" do
    type = relationship_types(:powers)
    relationship = relationships(:f1_powers_saturn_v)

    delete project_relationship_type_path(@project, type)

    assert_redirected_to structure_project_path(@project)
    assert flash[:alert].blank?, "a type with relationships is no longer a refusal"
    assert type.reload.discarded?
    assert relationship.reload.discarded?
  end

  # The state that had no exit before #66. The relationship was removed through
  # the UI, which discards it, so the structure page read "0 relationships"
  # while restrict_with_error kept refusing on a row nothing could reach.
  test "destroy succeeds when the only relationship of that kind is already deleted" do
    type = relationship_types(:powers)
    relationships(:f1_powers_saturn_v).discard!

    assert_difference -> { RelationshipType.kept.count }, -1 do
      delete project_relationship_type_path(@project, type)
    end

    assert flash[:alert].blank?
    assert type.reload.discarded?
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


  test "show states the shape" do
    get project_relationship_type_path(@project, relationship_types(:powers))

    assert_select ".badge", text: "Rocket Engine → Launch Vehicle"
  end

  test "the form says the description is the extraction context" do
    get new_project_relationship_type_path(@project)
    assert_match(/context for extracting relationships of this type from source material/, response.body)

    get edit_project_relationship_type_path(@project, relationship_types(:powers))
    assert_match(/context for extracting relationships of this type from source material/, response.body)
  end
end
