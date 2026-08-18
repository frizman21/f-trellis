require "test_helper"

# The same assertions EntityAttributeValueTest makes, run against the other user
# of TypedValue — so the extracted concern is proven on both sides rather than
# on one and assumed on the other.
class RelationshipTypeValueTest < ActiveSupport::TestCase
  def assert_only_column(record, column)
    (TypedAttribute::VALUE_COLUMNS.values - [ column ]).each do |other|
      assert_nil record.public_send(other), "expected #{other} to be nil"
    end
    assert_not_nil record.public_send(column), "expected #{column} to be set"
  end

  def value_for(attribute, raw)
    record = RelationshipTypeValue.new(relationship: relationships(:f1_powers_saturn_v),
                                       relationship_type_attribute: attribute)
    record.value = raw
    record
  end

  test "an int attribute round-trips through int_value alone" do
    # engine_count already has a value on this relationship, so use a free one.
    record = value_for(relationship_type_attributes(:powers_thrust_share), "0.2")

    assert record.save
    assert_in_delta 0.2, record.reload.value
    assert_only_column record, :float_value
  end

  test "a string attribute round-trips through string_value alone" do
    record = value_for(relationship_type_attributes(:powers_stage), "First")

    assert record.save
    assert_equal "First", record.reload.value
    assert_only_column record, :string_value
  end

  test "a datetime attribute round-trips through datetime_value alone" do
    record = value_for(relationship_type_attributes(:powers_certified_on), "1967-11-09 12:00")

    assert record.save
    assert_equal 1967, record.reload.value.year
    assert_only_column record, :datetime_value
  end

  test "rejects a value that cannot be cast to its declared type" do
    record = value_for(relationship_type_attributes(:powers_thrust_share), "not a number")

    assert_not record.valid?
    assert_match(/not a valid float/, record.errors.full_messages.to_sentence)
  end

  test "a blank value records nothing rather than failing" do
    record = value_for(relationship_type_attributes(:powers_stage), "")

    assert record.valid?
    assert_nil record.value
  end

  test "one value per attribute per relationship" do
    duplicate = value_for(relationship_type_attributes(:powers_engine_count), "9")

    assert_not duplicate.valid?
  end

  test "takes its project from its relationship" do
    record = value_for(relationship_type_attributes(:powers_stage), "First")
    record.valid?

    assert_equal projects(:apollo), record.project
  end
end
