require "test_helper"

class EntityTest < ActiveSupport::TestCase
  test "label is the value of the name attribute when there is one" do
    assert_equal "Rocketdyne F-1", entities(:f1).label
  end

  test "label falls back to type and id when the name attribute has no value" do
    entity = entities(:unnamed_engine)

    assert_equal "Rocket Engine ##{entity.id}", entity.label
  end

  test "label falls back when the type declares no name attribute at all" do
    entity = entities(:saturn_v)

    assert_equal "Launch Vehicle ##{entity.id}", entity.label
  end

  test "attribute_rows covers every attribute of the type, valued or not" do
    rows = entities(:f1).attribute_rows

    assert_equal entity_types(:rocket_engine).entity_type_attributes.map(&:name).sort,
                 rows.map { |attribute, _| attribute.name }.sort

    by_name = rows.to_h { |attribute, value| [ attribute.name, value ] }

    assert_equal "Rocketdyne F-1", by_name["name"].value
    # Declared on the type, never recorded on this entity: present as a row,
    # empty as a value. The show page renders the shape of the type too.
    assert_nil by_name["chambers"]
  end

  test "relationships include edges in both directions" do
    f1 = entities(:f1)
    saturn = entities(:saturn_v)
    incoming = Relationship.create!(from_entity: saturn, to_entity: entities(:unnamed_engine))

    assert_includes f1.relationships, relationships(:f1_powers_saturn_v)
    assert_includes entities(:unnamed_engine).relationships, incoming
    assert_includes saturn.relationships, relationships(:f1_powers_saturn_v)
    assert_includes saturn.relationships, incoming
  end

  test "deleting an entity takes its values and its relationships with it" do
    assert_difference [ -> { EntityAttributeValue.count }, -> { Relationship.count } ], -1 do
      entities(:saturn_v).destroy
    end
  end

  test "build_missing_attribute_values fills in only the gaps" do
    entity = entities(:f1)
    before = entity.entity_attribute_values.size

    entity.build_missing_attribute_values

    assert_equal entity_types(:rocket_engine).entity_type_attributes.size,
                 entity.entity_attribute_values.size
    assert_operator entity.entity_attribute_values.size, :>, before
  end
end
