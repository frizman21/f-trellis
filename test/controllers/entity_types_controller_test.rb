require "test_helper"

class EntityTypesControllerTest < ActionDispatch::IntegrationTest
  setup { @project = projects(:apollo) }

  test "index renders and lists each type with its counts" do
    get project_entity_types_path(@project)

    assert_response :success
    assert_select "h1", "Entity Types"
    assert_select "a", text: "Rocket Engine"
  end

  test "show lists the type's attributes and their value types" do
    get project_entity_type_path(@project, entity_types(:rocket_engine))

    assert_response :success
    assert_select "td", text: "thrust_kn"
    assert_select "td", text: "float"
  end

  test "show links the entities of the type" do
    get project_entity_type_path(@project, entity_types(:rocket_engine))

    assert_select "a[href=?]", project_entity_path(@project, entities(:f1))
  end

  test "show renders empty states for a type with no attributes and no entities" do
    type = @project.entity_types.create!(name: "Lonely")

    get project_entity_type_path(@project, type)

    assert_response :success
    assert_match(/No attributes defined/, response.body)
    assert_match(/No entities of this type yet/, response.body)
  end

  test "create makes a type" do
    assert_difference -> { EntityType.count }, 1 do
      post project_entity_types_path(@project), params: { entity_type: { name: "Spacecraft", description: "A ship." } }
    end

    assert_redirected_to project_entity_type_path(@project, EntityType.find_by(name: "Spacecraft"))
  end

  test "create rejects a duplicate name and makes nothing" do
    assert_no_difference -> { EntityType.count } do
      post project_entity_types_path(@project), params: { entity_type: { name: "Rocket Engine" } }
    end

    assert_response :unprocessable_entity
  end

  test "update renames a type" do
    type = entity_types(:launch_vehicle)

    patch project_entity_type_path(@project, type), params: { entity_type: { name: "Launcher" } }

    assert_redirected_to project_entity_type_path(@project, type)
    assert_equal "Launcher", type.reload.name
  end

  test "update rejects a blank name" do
    type = entity_types(:launch_vehicle)

    patch project_entity_type_path(@project, type), params: { entity_type: { name: "" } }

    assert_response :unprocessable_entity
    assert_equal "Launch Vehicle", type.reload.name
  end

  test "destroy removes a type nothing is an instance of" do
    type = @project.entity_types.create!(name: "Disposable")

    assert_difference -> { EntityType.count }, -1 do
      delete project_entity_type_path(@project, type)
    end

    assert_redirected_to project_entity_types_path(@project)
  end

  # A type with instances is not something to cascade away on a button press.
  test "destroy refuses a type that still has entities and says why" do
    type = entity_types(:rocket_engine)

    assert_no_difference -> { EntityType.count } do
      delete project_entity_type_path(@project, type)
    end

    assert_redirected_to project_entity_type_path(@project, type)
    assert flash[:alert].present?
  end

  # --- scoping ---------------------------------------------------------------

  test "index shows only this project's entity types" do
    get project_entity_types_path(@project)

    assert_response :success
    assert_select "a", text: "Rocket Engine"
    assert_select "a", text: "Capsule", count: 0
    assert_select "tbody tr", @project.entity_types.count
  end

  test "another project's entity type is not found under this project" do
    get project_entity_type_path(@project, entity_types(:gemini_capsule))

    assert_response :not_found
  end

  test "create assigns the project from the url" do
    post project_entity_types_path(@project), params: { entity_type: { name: "Spacecraft" } }

    assert_equal @project, EntityType.find_by(name: "Spacecraft").project
  end

  # The uniqueness of a type name is per project: two projects describing a
  # "Capsule" each is the normal case, not a collision.
  test "a name used in another project is free in this one" do
    assert_difference -> { EntityType.count }, 1 do
      post project_entity_types_path(@project), params: { entity_type: { name: "Capsule" } }
    end
  end

  test "the ontology side renders the project header" do
    get project_entity_types_path(@project)

    assert_select "a[href=?]", projects_path
    assert_select "a.nav-link.active[href=?]", project_entity_types_path(@project)
    assert_select "a.nav-link[href=?]", project_entities_path(@project)
  end
end
