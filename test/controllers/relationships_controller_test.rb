require "test_helper"

class RelationshipsControllerTest < ActionDispatch::IntegrationTest
  test "create adds an edge and returns to the entity it was added from" do
    assert_difference -> { Relationship.count }, 1 do
      post relationships_path, params: {
        relationship: { from_entity_id: entities(:f1).id, to_entity_id: entities(:bare).id }
      }
    end

    assert_redirected_to entity_path(entities(:f1))
  end

  test "create refuses an edge from an entity to itself and says why" do
    assert_no_difference -> { Relationship.count } do
      post relationships_path, params: {
        relationship: { from_entity_id: entities(:f1).id, to_entity_id: entities(:f1).id }
      }
    end

    assert_redirected_to entity_path(entities(:f1))
    assert flash[:alert].present?
  end

  test "destroy removes the edge and returns to the end it was removed from" do
    relationship = relationships(:f1_powers_saturn_v)

    assert_difference -> { Relationship.count }, -1 do
      # Removed from the `to` end, so it must come back here and not to the
      # `from` end the record happens to name first.
      delete relationship_path(relationship, entity_id: entities(:saturn_v).id)
    end

    assert_redirected_to entity_path(entities(:saturn_v))
  end

  test "destroy without an origin falls back to the from end" do
    relationship = relationships(:f1_powers_saturn_v)

    delete relationship_path(relationship)

    assert_redirected_to entity_path(entities(:f1))
  end
end
