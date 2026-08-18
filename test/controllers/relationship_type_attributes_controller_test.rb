require "test_helper"

class RelationshipTypeAttributesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:apollo)
    @type = relationship_types(:bare_relation)
  end

  test "new renders the form with the four value types on offer" do
    get new_project_relationship_type_relationship_type_attribute_path(@project, @type)

    assert_response :success
    RelationshipTypeAttribute::VALUE_TYPES.each do |value_type|
      assert_select "option[value=?]", value_type
    end
  end

  test "create adds an attribute to the type" do
    assert_difference -> { @type.relationship_type_attributes.count }, 1 do
      post project_relationship_type_relationship_type_attributes_path(@project, @type),
           params: { relationship_type_attribute: { name: "since", value_type: "datetime" } }
    end

    assert_redirected_to project_relationship_type_path(@project, @type)
  end

  test "create rejects a value type outside the four allowed" do
    assert_no_difference -> { RelationshipTypeAttribute.count } do
      post project_relationship_type_relationship_type_attributes_path(@project, @type),
           params: { relationship_type_attribute: { name: "flies", value_type: "boolean" } }
    end

    assert_response :unprocessable_entity
  end

  test "update renames an attribute" do
    attribute = relationship_type_attributes(:powers_stage)
    type = relationship_types(:powers)

    patch project_relationship_type_relationship_type_attribute_path(@project, type, attribute),
          params: { relationship_type_attribute: { name: "stage_name", value_type: "string" } }

    assert_equal "stage_name", attribute.reload.name
  end

  test "destroy is refused for an attribute that has been used" do
    attribute = relationship_type_attributes(:powers_engine_count)
    type = relationship_types(:powers)

    assert_no_difference [ -> { RelationshipTypeAttribute.count }, -> { RelationshipTypeValue.count } ] do
      delete project_relationship_type_relationship_type_attribute_path(@project, type, attribute)
    end

    assert flash[:alert].present?
  end

  test "destroy removes an attribute nothing has been recorded against" do
    unused = @type.relationship_type_attributes.create!(name: "notes", value_type: "string")

    assert_difference -> { RelationshipTypeAttribute.count }, -1 do
      delete project_relationship_type_relationship_type_attribute_path(@project, @type, unused)
    end
  end
end
