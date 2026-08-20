require "test_helper"

# The four citation models differ only in what they point at, so the rules are
# asserted once across all four rather than four times in four files. A rule
# that held for entities and quietly did not for relationship values is exactly
# what a shared concern is supposed to make impossible.
class SourceCitationTest < ActiveSupport::TestCase
  # Every citation names the run that recorded it (#71), so the run is part of
  # the minimum a valid one needs.
  # Not `run` — that is Minitest's own method and overriding it stops the
  # suite dead.
  def recorded_by
    @recorded_by ||= an_extraction_run(project: projects(:apollo), source: sources(:one))
  end

  def a_second_run
    @a_second_run ||= an_extraction_run(project: projects(:apollo), source: sources(:one))
  end

  def citations
    {
      EntityExtractionRun                => { entity: entities(:f1) },
      RelationshipExtractionRun          => { relationship: relationships(:f1_powers_saturn_v) },
      EntityAttributeValueExtractionRun  => { entity_attribute_value: entity_attribute_values(:f1_manufacturer) },
      RelationshipTypeValueExtractionRun => {
        relationship_type_value: relationship_type_values(:f1_powers_saturn_v_engine_count)
      }
    }
  end

  test "every citation requires a source" do
    citations.each do |klass, owner|
      assert_not klass.new(**owner, extraction_run: recorded_by).valid?, "#{klass} should require a source"
    end
  end

  test "every citation requires what it cites for" do
    citations.each_key do |klass|
      assert_not klass.new(source: sources(:one), extraction_run: recorded_by).valid?, "#{klass} should require an owner"
    end
  end

  test "confidence defaults to 100" do
    citations.each do |klass, owner|
      assert_equal 100, klass.new(**owner, source: sources(:one), extraction_run: recorded_by).confidence
    end
  end

  # An inclusive 1..100 range is the easy thing to get off by one, so both
  # boundaries and both neighbours are asserted.
  test "confidence accepts 1 and 100 and rejects 0 and 101" do
    citations.each do |klass, owner|
      assert klass.new(**owner, source: sources(:one), extraction_run: recorded_by, confidence: 1).valid?
      assert klass.new(**owner, source: sources(:one), extraction_run: recorded_by, confidence: 100).valid?
      assert_not klass.new(**owner, source: sources(:one), extraction_run: recorded_by, confidence: 0).valid?
      assert_not klass.new(**owner, source: sources(:one), extraction_run: recorded_by, confidence: 101).valid?
      assert_not klass.new(**owner, source: sources(:one), extraction_run: recorded_by, confidence: nil).valid?
    end
  end

  test "the same source cannot be cited twice for the same record in one run" do
    citations.each do |klass, owner|
      klass.create!(**owner, source: sources(:one), extraction_run: recorded_by)

      assert_not klass.new(**owner, source: sources(:one), extraction_run: recorded_by).valid?,
                 "#{klass} should reject a duplicate citation"
      assert klass.new(**owner, source: sources(:two), extraction_run: recorded_by).valid?,
             "#{klass} should allow a different source"
    end
  end

  # The rule #71 changed. Seeing the same fact on the same page in a second run
  # is a second sighting, and recording it is the point of putting the run on
  # the row — before this, the second extraction updated one row and the fact
  # that it had been seen again was lost.
  test "the same source may be cited again for the same record by another run" do
    citations.each do |klass, owner|
      klass.create!(**owner, source: sources(:one), extraction_run: recorded_by)

      assert klass.new(**owner, source: sources(:one),
                       extraction_run: a_second_run).valid?,
             "#{klass} should allow a second run to cite the same page"
    end
  end

  test "every citation requires the run that recorded it" do
    citations.each do |klass, owner|
      assert_not klass.new(**owner, source: sources(:one)).valid?,
                 "#{klass} should require an extraction run"
    end
  end

  test "two different records may cite the same source" do
    EntityExtractionRun.create!(entity: entities(:f1), source: sources(:one), extraction_run: recorded_by)

    assert EntityExtractionRun.new(entity: entities(:saturn_v), source: sources(:one), extraction_run: recorded_by).valid?
  end

  # --- what a deletion takes with it -----------------------------------------

  test "destroying the cited record destroys its citations" do
    EntityExtractionRun.create!(entity: entities(:bare), source: sources(:one), extraction_run: recorded_by)

    assert_difference -> { EntityExtractionRun.count }, -1 do
      entities(:bare).destroy
    end
  end

  # Losing the page a fact came from must not lose the fact.
  test "a source that is still cited cannot be destroyed" do
    EntityExtractionRun.create!(entity: entities(:f1), source: sources(:one), extraction_run: recorded_by)

    assert_not sources(:one).destroy
    assert Source.exists?(sources(:one).id)
    assert Entity.exists?(entities(:f1).id)
  end
end
