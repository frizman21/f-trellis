require "test_helper"

# Soft delete for entities and relationships. What is recorded is knowledge, and
# a mis-click should not be the end of it.
class SoftDeleteTest < ActiveSupport::TestCase
  setup { @project = projects(:apollo) }

  test "discarding an entity keeps the row and takes it out of kept" do
    entity = entities(:f1)

    assert_no_difference -> { Entity.count } do
      entity.discard
    end

    assert Entity.exists?(entity.id)
    assert_not_includes Entity.kept, entity
    assert_includes Entity.discarded, entity
  end

  # An edge to something no longer there is not a fact, and leaving it live puts
  # a dangling row in the other end's table.
  test "discarding an entity discards the edges it is the from end of" do
    entity = entities(:f1)
    edge = relationships(:f1_powers_saturn_v)

    entity.discard_with_relationships

    assert_predicate edge.reload, :discarded?
  end

  # The easy half is the one you wrote the query for; this is the other.
  test "discarding an entity discards the edges it is the to end of" do
    entity = entities(:saturn_v)
    edge = relationships(:f1_powers_saturn_v)

    entity.discard_with_relationships

    assert_predicate edge.reload, :discarded?
  end

  test "a discarded entity's edges leave the other end's table" do
    entities(:f1).discard_with_relationships

    assert_not_includes entities(:saturn_v).relationships.kept, relationships(:f1_powers_saturn_v)
  end

  # Soft delete keeps things; a cascade here would defeat the point.
  test "a discarded entity keeps its values and its citations" do
    entity = entities(:f1)
    EntityExtractionRun.create!(entity: entity, source: sources(:one),
                                extraction_run: an_extraction_run(project: entity.project,
                                                                  source: sources(:one)))

    assert_no_difference [ -> { EntityAttributeValue.count }, -> { EntityExtractionRun.count } ] do
      entity.discard_with_relationships
    end
  end

  test "undiscarding brings an entity back" do
    entity = entities(:f1)
    entity.discard

    assert_not_includes Entity.kept, entity

    entity.undiscard

    assert_includes Entity.kept, entity
  end

  test "a discarded relationship keeps its values" do
    assert_no_difference -> { RelationshipTypeValue.count } do
      relationships(:f1_powers_saturn_v).discard
    end
  end

  # The project is going; a soft-deleted entity inside a deleted project is not
  # something to keep.
  test "destroying a project removes discarded rows with the rest" do
    entities(:f1).discard_with_relationships

    @project.destroy

    assert_not Entity.exists?(entities(:f1).id)
  end

  # No default scope: one that hides rows is invisible at the call site and
  # surprises every query written later.
  test "the models declare no default scope hiding discarded rows" do
    entities(:f1).discard

    assert_includes Entity.all, entities(:f1)
    assert_includes @project.entities, entities(:f1)
  end
end
