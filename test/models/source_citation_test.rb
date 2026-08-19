require "test_helper"

# The four citation models differ only in what they point at, so the rules are
# asserted once across all four rather than four times in four files. A rule
# that held for entities and quietly did not for relationship values is exactly
# what a shared concern is supposed to make impossible.
class SourceCitationTest < ActiveSupport::TestCase
  def citations
    {
      EntitySource                => { entity: entities(:f1) },
      RelationshipSource          => { relationship: relationships(:f1_powers_saturn_v) },
      EntityAttributeValueSource  => { entity_attribute_value: entity_attribute_values(:f1_manufacturer) },
      RelationshipTypeValueSource => {
        relationship_type_value: relationship_type_values(:f1_powers_saturn_v_engine_count)
      }
    }
  end

  test "every citation requires a source" do
    citations.each do |klass, owner|
      assert_not klass.new(**owner).valid?, "#{klass} should require a source"
    end
  end

  test "every citation requires what it cites for" do
    citations.each_key do |klass|
      assert_not klass.new(source: sources(:one)).valid?, "#{klass} should require an owner"
    end
  end

  test "confidence defaults to 100" do
    citations.each do |klass, owner|
      assert_equal 100, klass.new(**owner, source: sources(:one)).confidence
    end
  end

  # An inclusive 1..100 range is the easy thing to get off by one, so both
  # boundaries and both neighbours are asserted.
  test "confidence accepts 1 and 100 and rejects 0 and 101" do
    citations.each do |klass, owner|
      assert klass.new(**owner, source: sources(:one), confidence: 1).valid?
      assert klass.new(**owner, source: sources(:one), confidence: 100).valid?
      assert_not klass.new(**owner, source: sources(:one), confidence: 0).valid?
      assert_not klass.new(**owner, source: sources(:one), confidence: 101).valid?
      assert_not klass.new(**owner, source: sources(:one), confidence: nil).valid?
    end
  end

  test "the same source cannot be cited twice for the same record" do
    citations.each do |klass, owner|
      klass.create!(**owner, source: sources(:one))

      assert_not klass.new(**owner, source: sources(:one)).valid?,
                 "#{klass} should reject a duplicate citation"
      assert klass.new(**owner, source: sources(:two)).valid?,
             "#{klass} should allow a different source"
    end
  end

  test "two different records may cite the same source" do
    EntitySource.create!(entity: entities(:f1), source: sources(:one))

    assert EntitySource.new(entity: entities(:saturn_v), source: sources(:one)).valid?
  end

  # --- what a deletion takes with it -----------------------------------------

  test "destroying the cited record destroys its citations" do
    EntitySource.create!(entity: entities(:bare), source: sources(:one))

    assert_difference -> { EntitySource.count }, -1 do
      entities(:bare).destroy
    end
  end

  # Losing the page a fact came from must not lose the fact.
  test "a source that is still cited cannot be destroyed" do
    EntitySource.create!(entity: entities(:f1), source: sources(:one))

    assert_not sources(:one).destroy
    assert Source.exists?(sources(:one).id)
    assert Entity.exists?(entities(:f1).id)
  end
end
