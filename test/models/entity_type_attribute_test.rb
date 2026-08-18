require "test_helper"

class EntityTypeAttributeTest < ActiveSupport::TestCase
  def build(**overrides)
    EntityTypeAttribute.new({ entity_type: entity_types(:launch_vehicle),
                              name: "mass_kg", value_type: "float" }.merge(overrides))
  end

  test "requires a name" do
    assert_not build(name: nil).valid?
  end

  test "requires a value type" do
    assert_not build(value_type: nil).valid?
  end

  test "rejects a value type outside the four allowed" do
    attribute = build(value_type: "boolean")

    assert_not attribute.valid?
    assert_match(/must be one of/, attribute.errors.full_messages.to_sentence)
  end

  test "accepts each of the four allowed value types" do
    EntityTypeAttribute::VALUE_TYPES.each do |value_type|
      assert build(name: "attr_#{value_type}", value_type: value_type).valid?,
             "#{value_type} should be a valid value type"
    end
  end

  test "rejects a duplicate name within the same type but allows it across types" do
    assert_not build(entity_type: entity_types(:rocket_engine), name: "thrust_kn").valid?
    assert build(entity_type: entity_types(:launch_vehicle), name: "thrust_kn").valid?
  end

  test "maps each value type to its storage column" do
    assert_equal :int_value,      build(value_type: "int").value_column
    assert_equal :float_value,    build(value_type: "float").value_column
    assert_equal :string_value,   build(value_type: "string").value_column
    assert_equal :datetime_value, build(value_type: "datetime").value_column
  end
end
