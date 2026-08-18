require "test_helper"

class EntityAttributeValueTest < ActiveSupport::TestCase
  # The whole point of the four-column design is that exactly one column is
  # live. A value that also wrote one of the others would read back correctly
  # today and wrongly the moment an attribute's type changed.
  def assert_only_column(record, column)
    live = EntityTypeAttribute::VALUE_COLUMNS.values
    (live - [ column ]).each do |other|
      assert_nil record.public_send(other), "expected #{other} to be nil"
    end
    assert_not_nil record.public_send(column), "expected #{column} to be set"
  end

  def value_for(attribute, raw)
    record = EntityAttributeValue.new(entity: entities(:unnamed_engine),
                                      entity_type_attribute: attribute)
    record.value = raw
    record
  end

  test "an int attribute round-trips through int_value alone" do
    record = value_for(entity_type_attributes(:engine_chambers), "5")

    assert record.save
    assert_equal 5, record.reload.value
    assert_only_column record, :int_value
  end

  test "a float attribute round-trips through float_value alone" do
    record = value_for(entity_type_attributes(:engine_thrust), "6770.5")

    assert record.save
    assert_in_delta 6770.5, record.reload.value
    assert_only_column record, :float_value
  end

  test "a string attribute round-trips through string_value alone" do
    record = value_for(entity_type_attributes(:engine_name), "Merlin")

    assert record.save
    assert_equal "Merlin", record.reload.value
    assert_only_column record, :string_value
  end

  test "a datetime attribute round-trips through datetime_value alone" do
    record = value_for(entity_type_attributes(:engine_first_flight), "1967-11-09 12:00")

    assert record.save
    assert_equal 1967, record.reload.value.year
    assert_only_column record, :datetime_value
  end

  test "rejects a value that cannot be cast to its declared type" do
    record = value_for(entity_type_attributes(:engine_chambers), "not a number")

    assert_not record.valid?
    assert_match(/not a valid int/, record.errors.full_messages.to_sentence)
  end

  test "a blank value records nothing rather than failing" do
    record = value_for(entity_type_attributes(:engine_chambers), "")

    assert record.valid?
    assert_nil record.value
  end

  test "rewriting a value clears the columns it no longer belongs in" do
    record = value_for(entity_type_attributes(:engine_chambers), "5")
    record.save!
    record.entity_type_attribute = entity_type_attributes(:engine_name)
    record.value = "Merlin"

    assert_nil record.int_value
    assert_equal "Merlin", record.string_value
  end

  test "one value per attribute per entity" do
    duplicate = EntityAttributeValue.new(entity: entities(:f1),
                                         entity_type_attribute: entity_type_attributes(:engine_name))
    duplicate.value = "Another name"

    assert_not duplicate.valid?
  end

  test "display_value renders a datetime readably and nothing for a missing value" do
    record = value_for(entity_type_attributes(:engine_first_flight), "1967-11-09 12:00")

    assert_equal "1967-11-09 12:00", record.display_value
    assert_equal "", value_for(entity_type_attributes(:engine_chambers), "").display_value
  end
end
