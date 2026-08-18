require "test_helper"

class EntityTypeAttributesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:apollo)
    @type = entity_types(:launch_vehicle)
  end

  test "new renders the form with the four value types on offer" do
    get new_project_entity_type_entity_type_attribute_path(@project, @type)

    assert_response :success
    EntityTypeAttribute::VALUE_TYPES.each do |value_type|
      assert_select "option[value=?]", value_type
    end
  end

  test "create adds an attribute to the type" do
    assert_difference -> { @type.entity_type_attributes.count }, 1 do
      post project_entity_type_entity_type_attributes_path(@project, @type),
           params: { entity_type_attribute: { name: "mass_kg", value_type: "float" } }
    end

    assert_redirected_to project_entity_type_path(@project, @type)
  end

  test "create rejects a value type outside the four allowed" do
    assert_no_difference -> { EntityTypeAttribute.count } do
      post project_entity_type_entity_type_attributes_path(@project, @type),
           params: { entity_type_attribute: { name: "flies", value_type: "boolean" } }
    end

    assert_response :unprocessable_entity
  end

  test "create rejects a name already used on the same type" do
    assert_no_difference -> { EntityTypeAttribute.count } do
      post project_entity_type_entity_type_attributes_path(@project, @type),
           params: { entity_type_attribute: { name: "stages", value_type: "int" } }
    end

    assert_response :unprocessable_entity
  end

  test "update renames an attribute" do
    attribute = entity_type_attributes(:vehicle_stages)

    patch project_entity_type_entity_type_attribute_path(@project, @type, attribute),
          params: { entity_type_attribute: { name: "stage_count", value_type: "int" } }

    assert_redirected_to project_entity_type_path(@project, @type)
    assert_equal "stage_count", attribute.reload.name
  end

  # Deleting a used attribute would delete the values recorded under it, which
  # are knowledge rather than schema.
  test "destroy is refused for an attribute that has been used" do
    attribute = entity_type_attributes(:vehicle_stages)

    assert_no_difference [ -> { EntityTypeAttribute.count }, -> { EntityAttributeValue.count } ] do
      delete project_entity_type_entity_type_attribute_path(@project, @type, attribute)
    end

    assert flash[:alert].present?
  end

  test "destroy removes an attribute nothing has been recorded against" do
    unused = @type.entity_type_attributes.create!(name: "range_km", value_type: "float")

    assert_difference -> { EntityTypeAttribute.count }, -1 do
      delete project_entity_type_entity_type_attribute_path(@project, @type, unused)
    end

    assert_redirected_to project_entity_type_path(@project, @type)
  end

  test "the type page offers Disable for a used attribute and Delete for an unused one" do
    unused = @type.entity_type_attributes.create!(name: "range_km", value_type: "float")

    get project_entity_type_path(@project, @type)

    assert_response :success
    assert_select "form[action=?]",
                  toggle_disabled_project_entity_type_entity_type_attribute_path(@project, @type, entity_type_attributes(:vehicle_stages))
    assert_select "form[action=?]",
                  project_entity_type_entity_type_attribute_path(@project, @type, unused)
  end

  test "disabling and enabling round-trips from the page" do
    attribute = entity_type_attributes(:vehicle_stages)

    patch toggle_disabled_project_entity_type_entity_type_attribute_path(@project, @type, attribute)
    assert_predicate attribute.reload, :is_disabled?

    patch toggle_disabled_project_entity_type_entity_type_attribute_path(@project, @type, attribute)
    assert_not attribute.reload.is_disabled?
  end
end
