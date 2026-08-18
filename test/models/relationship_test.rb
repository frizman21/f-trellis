require "test_helper"

class RelationshipTest < ActiveSupport::TestCase
  test "requires both ends" do
    assert_not Relationship.new(from_entity: entities(:f1)).valid?
    assert_not Relationship.new(to_entity: entities(:f1)).valid?
  end

  test "rejects an edge from an entity to itself" do
    relationship = Relationship.new(from_entity: entities(:f1), to_entity: entities(:f1))

    assert_not relationship.valid?
  end

  test "other_end returns the far entity from either side" do
    relationship = relationships(:f1_powers_saturn_v)

    assert_equal entities(:saturn_v), relationship.other_end(entities(:f1))
    assert_equal entities(:f1),       relationship.other_end(entities(:saturn_v))
  end

  # --- typing ----------------------------------------------------------------

  test "requires a relationship type" do
    relationship = Relationship.new(from_entity: entities(:f1), to_entity: entities(:bare))

    assert_not relationship.valid?
  end

  test "rejects a relationship type from another project" do
    relationship = Relationship.new(relationship_type: relationship_types(:gemini_docks),
                                    from_entity: entities(:f1), to_entity: entities(:bare))

    assert_not relationship.valid?
  end

  test "attribute_rows covers every attribute of the type, valued or not" do
    rows = relationships(:f1_powers_saturn_v).attribute_rows
    by_name = rows.to_h { |attribute, value| [ attribute.name, value ] }

    assert_equal relationship_types(:powers).relationship_type_attributes.map(&:name).sort,
                 by_name.keys.sort
    assert_equal 5, by_name["engine_count"].value
    # Declared on the type, never recorded on this edge: a row, but a blank one.
    assert_nil by_name["stage"]
  end

  test "deleting a relationship takes its values with it" do
    assert_difference -> { RelationshipTypeValue.count }, -1 do
      relationships(:f1_powers_saturn_v).destroy
    end
  end

  # --- the ends the type declares --------------------------------------------

  def build(**overrides)
    Relationship.new({ relationship_type: relationship_types(:powers),
                       from_entity: entities(:f1),
                       to_entity: entities(:saturn_v) }.merge(overrides))
  end

  test "an edge matching both declared ends is valid" do
    assert build.valid?
  end

  test "a from entity of the wrong type is rejected, and the error names that end" do
    relationship = build(from_entity: entities(:saturn_v), to_entity: entities(:saturn_v))

    assert_not relationship.valid?
    assert_includes relationship.errors.attribute_names, :from_entity
    assert_match(/must be a Rocket Engine/, relationship.errors.full_messages.to_sentence)
  end

  test "a to entity of the wrong type is rejected" do
    relationship = build(to_entity: entities(:bare))

    assert_not relationship.valid?
    assert_includes relationship.errors.attribute_names, :to_entity
  end

  # The one a naive "are these two types involved?" check would wrongly pass.
  # Powers runs engine → vehicle; the same two entities the other way round is a
  # different claim, and not one this type permits.
  test "direction is not symmetric" do
    forwards = build(from_entity: entities(:f1), to_entity: entities(:saturn_v))
    backwards = build(from_entity: entities(:saturn_v), to_entity: entities(:f1))

    assert forwards.valid?
    assert_not backwards.valid?
  end

  test "a type with the same entity type at both ends accepts either ordering" do
    assert build(relationship_type: relationship_types(:supersedes),
                 from_entity: entities(:f1), to_entity: entities(:unnamed_engine)).valid?
    assert build(relationship_type: relationship_types(:supersedes),
                 from_entity: entities(:unnamed_engine), to_entity: entities(:f1)).valid?
  end
end
