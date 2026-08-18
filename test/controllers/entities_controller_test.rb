require "test_helper"

class EntitiesControllerTest < ActionDispatch::IntegrationTest
  # --- index -----------------------------------------------------------------

  test "index renders and labels each entity" do
    get entities_path

    assert_response :success
    assert_select "h1", "Entities"
    assert_select "a", text: "Rocketdyne F-1"
  end

  test "index shows the empty state when there are no entities" do
    Relationship.delete_all
    EntityAttributeValue.delete_all
    Entity.delete_all

    get entities_path

    assert_response :success
    assert_match(/No entities yet/, response.body)
  end

  # --- show: the attributes table -------------------------------------------

  test "show renders one attribute row per attribute of the type" do
    get entity_path(entities(:f1))

    assert_response :success
    assert_select "h1", "Rocketdyne F-1"
    # Four attributes on Rocket Engine, plus the header row.
    assert_select "table:first-of-type tbody tr", 4
  end

  test "show renders each attribute's name in the first column and value in the second" do
    get entity_path(entities(:f1))

    assert_select "table:first-of-type tbody tr" do |rows|
      cells = rows.map { |row| row.css("td").map { |td| td.text.strip } }
      by_name = cells.to_h { |name, value| [ name.split.first, value ] }

      assert_equal "Rocketdyne F-1", by_name["name"]
      assert_equal "6770.0", by_name["thrust_kn"]
      # Declared on the type, never recorded: a blank row rather than a missing
      # one, so the page shows the shape of the type as well as the content.
      assert_equal "", by_name["chambers"]
    end
  end

  test "show renders an empty state when the type declares no attributes" do
    get entity_path(entities(:bare))

    assert_response :success
    assert_match(/defines no attributes yet/, response.body)
  end

  # --- show: the relationships table -----------------------------------------

  test "show lists a relationship where the entity is the from end, linking to the other entity" do
    get entity_path(entities(:f1))

    assert_response :success
    assert_select "a[href=?]", entity_path(entities(:saturn_v))
  end

  test "show lists a relationship where the entity is the to end, linking to the other entity" do
    get entity_path(entities(:saturn_v))

    assert_response :success
    # The far end from Saturn V is the F-1, not itself. Asserted from this side
    # too because linking back to the current page is the easy mistake here.
    assert_select "a[href=?]", entity_path(entities(:f1))
    assert_select "a[href=?]", entity_path(entities(:saturn_v)), count: 0
  end

  test "show reports the direction of each relationship" do
    get entity_path(entities(:f1))
    assert_match(/→ to/, response.body)

    get entity_path(entities(:saturn_v))
    assert_match(/← from/, response.body)
  end

  test "show renders an empty state when the entity has no relationships" do
    get entity_path(entities(:bare))

    assert_response :success
    assert_match(/No relationships yet/, response.body)
  end

  # --- create ----------------------------------------------------------------

  test "new renders the type picker" do
    get new_entity_path

    assert_response :success
    assert_select "select[name=?]", "entity[entity_type_id]"
  end

  test "create makes an entity and sends you on to fill in its attributes" do
    assert_difference -> { Entity.count }, 1 do
      post entities_path, params: { entity: { entity_type_id: entity_types(:rocket_engine).id } }
    end

    assert_redirected_to edit_entity_path(Entity.order(:id).last)
  end

  test "create without a type creates nothing" do
    assert_no_difference -> { Entity.count } do
      post entities_path, params: { entity: { entity_type_id: nil } }
    end

    assert_response :unprocessable_entity
  end

  # --- edit and update -------------------------------------------------------

  test "edit offers a field for every attribute of the type" do
    get edit_entity_path(entities(:f1))

    assert_response :success
    # One value input per attribute of the type — the hidden id and
    # entity_type_attribute_id fields are counted separately on purpose, so this
    # asserts what a person can fill in rather than how many inputs exist.
    assert_select "form input[name*=?]", "[value]", count: 4
    assert_select "form label", text: "chambers"
  end

  test "update records a value for an attribute that had none" do
    entity = entities(:f1)
    chambers = entity_type_attributes(:engine_chambers)

    patch entity_path(entity), params: {
      entity: { entity_attribute_values_attributes: {
        "0" => { entity_type_attribute_id: chambers.id, value: "5" }
      } }
    }

    assert_redirected_to entity_path(entity)
    assert_equal 5, entity.reload.value_for("chambers")
  end

  test "update changes a value that already existed" do
    entity = entities(:f1)
    existing = entity_attribute_values(:f1_name)

    patch entity_path(entity), params: {
      entity: { entity_attribute_values_attributes: {
        "0" => { id: existing.id, entity_type_attribute_id: existing.entity_type_attribute_id,
                 value: "Rocketdyne F-1A" }
      } }
    }

    assert_equal "Rocketdyne F-1A", entity.reload.value_for("name")
  end

  test "update rejects a value that does not fit its declared type" do
    entity = entities(:f1)
    chambers = entity_type_attributes(:engine_chambers)

    patch entity_path(entity), params: {
      entity: { entity_attribute_values_attributes: {
        "0" => { entity_type_attribute_id: chambers.id, value: "not a number" }
      } }
    }

    assert_response :unprocessable_entity
    assert_nil entity.reload.value_for("chambers")
  end

  test "a blank field for an unrecorded attribute records nothing" do
    entity = entities(:f1)
    chambers = entity_type_attributes(:engine_chambers)

    assert_no_difference -> { EntityAttributeValue.count } do
      patch entity_path(entity), params: {
        entity: { entity_attribute_values_attributes: {
          "0" => { entity_type_attribute_id: chambers.id, value: "" }
        } }
      }
    end
  end

  # --- destroy ---------------------------------------------------------------

  test "destroy removes the entity" do
    assert_difference -> { Entity.count }, -1 do
      delete entity_path(entities(:bare))
    end

    assert_redirected_to entities_path
  end
end
