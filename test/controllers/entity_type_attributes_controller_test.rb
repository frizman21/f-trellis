require "test_helper"

class EntityTypeAttributesControllerTest < ActionDispatch::IntegrationTest
  setup { @type = entity_types(:launch_vehicle) }

  test "new renders the form with the four value types on offer" do
    get new_entity_type_entity_type_attribute_path(@type)

    assert_response :success
    EntityTypeAttribute::VALUE_TYPES.each do |value_type|
      assert_select "option[value=?]", value_type
    end
  end

  test "create adds an attribute to the type" do
    assert_difference -> { @type.entity_type_attributes.count }, 1 do
      post entity_type_entity_type_attributes_path(@type),
           params: { entity_type_attribute: { name: "mass_kg", value_type: "float" } }
    end

    assert_redirected_to entity_type_path(@type)
  end

  test "create rejects a value type outside the four allowed" do
    assert_no_difference -> { EntityTypeAttribute.count } do
      post entity_type_entity_type_attributes_path(@type),
           params: { entity_type_attribute: { name: "flies", value_type: "boolean" } }
    end

    assert_response :unprocessable_entity
  end

  test "create rejects a name already used on the same type" do
    assert_no_difference -> { EntityTypeAttribute.count } do
      post entity_type_entity_type_attributes_path(@type),
           params: { entity_type_attribute: { name: "stages", value_type: "int" } }
    end

    assert_response :unprocessable_entity
  end

  test "update renames an attribute" do
    attribute = entity_type_attributes(:vehicle_stages)

    patch entity_type_entity_type_attribute_path(@type, attribute),
          params: { entity_type_attribute: { name: "stage_count", value_type: "int" } }

    assert_redirected_to entity_type_path(@type)
    assert_equal "stage_count", attribute.reload.name
  end

  test "destroy removes an attribute and the values recorded against it" do
    attribute = entity_type_attributes(:vehicle_stages)

    assert_difference [ -> { EntityTypeAttribute.count }, -> { EntityAttributeValue.count } ], -1 do
      delete entity_type_entity_type_attribute_path(@type, attribute)
    end

    assert_redirected_to entity_type_path(@type)
  end
end
