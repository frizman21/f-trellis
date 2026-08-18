require "test_helper"

class EntityTest < ActiveSupport::TestCase
  # The name is a column now (#28). What used to be #label deriving one from an
  # attribute is gone, and a stale alias is exactly how two names for one thing
  # survive a rename.
  test "an entity has a name of its own and no derived label" do
    assert_equal "Rocketdyne F-1", entities(:f1).name
    assert_not entities(:f1).respond_to?(:label)
  end

  test "a name is required" do
    assert_not Entity.new(project: projects(:apollo), entity_type: entity_types(:bare)).valid?
    assert_not entities(:f1).tap { |e| e.name = "   " }.valid?
  end




  test "attribute_rows covers every attribute of the type, valued or not" do
    rows = entities(:f1).attribute_rows

    assert_equal entity_types(:rocket_engine).entity_type_attributes.map(&:name).sort,
                 rows.map { |attribute, _| attribute.name }.sort

    by_name = rows.to_h { |attribute, value| [ attribute.name, value ] }

    assert_equal "Rocketdyne", by_name["manufacturer"].value
    # Declared on the type, never recorded on this entity: present as a row,
    # empty as a value. The show page renders the shape of the type too.
    assert_nil by_name["chambers"]
  end

  test "relationships include edges in both directions" do
    f1 = entities(:f1)
    saturn = entities(:saturn_v)
    # Powers runs engine → vehicle, so the second edge is built that way round;
    # what the test is about is that both ends see it, not its direction.
    incoming = Relationship.create!(relationship_type: relationship_types(:powers),
                                    from_entity: entities(:unnamed_engine), to_entity: saturn)

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
