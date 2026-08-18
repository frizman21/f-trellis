require "test_helper"

class EntityTypeTest < ActiveSupport::TestCase
  test "requires a name" do
    type = EntityType.new(name: nil)

    assert_not type.valid?
    assert_includes type.errors.attribute_names, :name
  end

  test "rejects a duplicate name, regardless of case" do
    assert_not EntityType.new(name: "rocket engine").valid?
  end

  test "a type with entities of it cannot be deleted" do
    type = entity_types(:rocket_engine)

    assert_not type.destroy
    assert_predicate type.errors, :any?
    assert EntityType.exists?(type.id)
  end

  test "a type with no entities can be deleted, and takes its attributes with it" do
    type = EntityType.create!(name: "Disposable")
    type.entity_type_attributes.create!(name: "whatever", value_type: "string")

    assert_difference -> { EntityTypeAttribute.count }, -1 do
      assert type.destroy
    end
  end
end
