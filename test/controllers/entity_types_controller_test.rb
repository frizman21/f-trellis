require "test_helper"

class EntityTypesControllerTest < ActionDispatch::IntegrationTest
  test "index renders and lists each type with its counts" do
    get entity_types_path

    assert_response :success
    assert_select "h1", "Entity Types"
    assert_select "a", text: "Rocket Engine"
  end

  test "show lists the type's attributes and their value types" do
    get entity_type_path(entity_types(:rocket_engine))

    assert_response :success
    assert_select "td", text: "thrust_kn"
    assert_select "td", text: "float"
  end

  test "show links the entities of the type" do
    get entity_type_path(entity_types(:rocket_engine))

    assert_select "a[href=?]", entity_path(entities(:f1))
  end

  test "show renders empty states for a type with no attributes and no entities" do
    type = EntityType.create!(name: "Lonely")

    get entity_type_path(type)

    assert_response :success
    assert_match(/No attributes defined/, response.body)
    assert_match(/No entities of this type yet/, response.body)
  end

  test "create makes a type" do
    assert_difference -> { EntityType.count }, 1 do
      post entity_types_path, params: { entity_type: { name: "Spacecraft", description: "A ship." } }
    end

    assert_redirected_to entity_type_path(EntityType.find_by(name: "Spacecraft"))
  end

  test "create rejects a duplicate name and makes nothing" do
    assert_no_difference -> { EntityType.count } do
      post entity_types_path, params: { entity_type: { name: "Rocket Engine" } }
    end

    assert_response :unprocessable_entity
  end

  test "update renames a type" do
    type = entity_types(:launch_vehicle)

    patch entity_type_path(type), params: { entity_type: { name: "Launcher" } }

    assert_redirected_to entity_type_path(type)
    assert_equal "Launcher", type.reload.name
  end

  test "update rejects a blank name" do
    type = entity_types(:launch_vehicle)

    patch entity_type_path(type), params: { entity_type: { name: "" } }

    assert_response :unprocessable_entity
    assert_equal "Launch Vehicle", type.reload.name
  end

  test "destroy removes a type nothing is an instance of" do
    type = EntityType.create!(name: "Disposable")

    assert_difference -> { EntityType.count }, -1 do
      delete entity_type_path(type)
    end

    assert_redirected_to entity_types_path
  end

  # A type with instances is not something to cascade away on a button press.
  test "destroy refuses a type that still has entities and says why" do
    type = entity_types(:rocket_engine)

    assert_no_difference -> { EntityType.count } do
      delete entity_type_path(type)
    end

    assert_redirected_to entity_type_path(type)
    assert flash[:alert].present?
  end
end
