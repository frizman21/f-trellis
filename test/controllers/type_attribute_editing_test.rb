require "test_helper"

# A type is its name, its description and what it carries — all edited on one
# form. Attributes have no screens of their own.
class TypeAttributeEditingTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:apollo)
    @type = entity_types(:rocket_engine)
  end

  test "the edit page renders a row per attribute, filled in" do
    get edit_project_entity_type_path(@project, @type)

    assert_response :success
    @type.entity_type_attributes.each do |attribute|
      assert_select "input[value=?]", attribute.name
    end
  end

  test "the edit page carries a template row for adding" do
    get edit_project_entity_type_path(@project, @type)

    assert_select "[data-controller=?]", "nested-fields"
    assert_select "template[data-nested-fields-target=?]", "template"
  end

  test "saving a new row adds an attribute" do
    assert_difference -> { @type.entity_type_attributes.count }, 1 do
      patch project_entity_type_path(@project, @type), params: {
        entity_type: { name: @type.name,
                       entity_type_attributes_attributes: {
                         "99" => { name: "isp_seconds", value_type: "float",
                                   is_displayed_on_index: "1" }
                       } }
      }
    end

    added = @type.entity_type_attributes.find_by!(name: "isp_seconds")
    assert_equal "float", added.value_type
  end

  # A row someone did not fill in is not an error.
  test "a blank new row adds nothing" do
    assert_no_difference -> { EntityTypeAttribute.count } do
      patch project_entity_type_path(@project, @type), params: {
        entity_type: { name: @type.name,
                       entity_type_attributes_attributes: {
                         "99" => { name: "", value_type: "" }
                       } }
      }
    end
  end

  test "renaming an attribute in place works" do
    attribute = entity_type_attributes(:engine_thrust)

    patch project_entity_type_path(@project, @type), params: {
      entity_type: { name: @type.name,
                     entity_type_attributes_attributes: {
                       "0" => { id: attribute.id, name: "thrust_newtons", value_type: "float" }
                     } }
    }

    assert_equal "thrust_newtons", attribute.reload.name
  end

  test "an unused attribute can be deleted from the form" do
    unused = @type.entity_type_attributes.create!(name: "spare", value_type: "string")

    assert_difference -> { EntityTypeAttribute.count }, -1 do
      patch project_entity_type_path(@project, @type), params: {
        entity_type: { name: @type.name,
                       entity_type_attributes_attributes: {
                         "0" => { id: unused.id, name: unused.name,
                                  value_type: unused.value_type, _destroy: "1" }
                       } }
      }
    end
  end

  # The form offers Disable rather than Delete for a used attribute, because the
  # model refuses the deletion and the values are knowledge.
  test "a used attribute offers a disable checkbox and no delete" do
    get edit_project_entity_type_path(@project, @type)

    used = entity_type_attributes(:engine_manufacturer)
    assert used.used?

    # One control per row, chosen by whether the attribute has been used: the two
    # with values recorded offer Disable, the two without offer Delete. Counted
    # rather than located by index, since rows are ordered by name.
    used, unused = @type.entity_type_attributes.partition(&:used?)

    assert_equal 2, used.size
    assert_select "input[type=checkbox][name*=?]", "[is_disabled]", used.size
    assert_select "input[type=checkbox][name*=?]", "[_destroy]", unused.size
  end

  test "disabling an attribute from the form works and keeps its values" do
    attribute = entity_type_attributes(:engine_manufacturer)

    assert_no_difference -> { EntityAttributeValue.count } do
      patch project_entity_type_path(@project, @type), params: {
        entity_type: { name: @type.name,
                       entity_type_attributes_attributes: {
                         "0" => { id: attribute.id, name: attribute.name,
                                  value_type: attribute.value_type, is_disabled: "1" }
                       } }
      }
    end

    assert_predicate attribute.reload, :is_disabled?
  end

  test "an invalid value type re-renders and changes nothing" do
    attribute = entity_type_attributes(:engine_thrust)

    patch project_entity_type_path(@project, @type), params: {
      entity_type: { name: @type.name,
                     entity_type_attributes_attributes: {
                       "0" => { id: attribute.id, name: attribute.name, value_type: "boolean" }
                     } }
    }

    assert_response :unprocessable_entity
    assert_equal "float", attribute.reload.value_type
  end

  test "the same works for a relationship type" do
    type = relationship_types(:powers)

    assert_difference -> { type.relationship_type_attributes.count }, 1 do
      patch project_relationship_type_path(@project, type), params: {
        relationship_type: { name: type.name,
                             from_entity_type_id: type.from_entity_type_id,
                             to_entity_type_id: type.to_entity_type_id,
                             relationship_type_attributes_attributes: {
                               "99" => { name: "duration_days", value_type: "int" }
                             } }
      }
    end
  end

  # Two places to add an attribute is how the two drift.
  test "attributes have no screens of their own" do
    get "/projects/#{@project.id}/entity_types/#{@type.id}/entity_type_attributes/new"

    assert_response :not_found
  end

  test "the type's show page states its attributes without editing controls" do
    get project_entity_type_path(@project, @type)

    assert_response :success
    assert_select "td", text: "thrust_kn"
    assert_select "form[action*=?]", "entity_type_attributes", count: 0
  end
end
