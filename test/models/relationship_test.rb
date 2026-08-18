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
end
