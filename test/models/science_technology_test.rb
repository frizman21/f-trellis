require "test_helper"

# The invariants the relationship pattern rests on, exercised on the three new
# edges: one edge per pair, provenance is not optional, and the current pointer
# is set rather than inferred.
class ScienceTechnologyTest < ActiveSupport::TestCase
  setup do
    @report = SourceProcessingReport.create!(source: sources(:one),
                                             skill_revision: skill_revisions(:promoted_1),
                                             status: "processing")
    @science = Science.create!
    @technology = Technology.create!
    @part = Part.create!
    @person = Person.create!
  end

  test "a pair may only be connected once" do
    ScienceTechnology.create!(science: @science, technology: @technology)

    assert_raises(ActiveRecord::RecordNotUnique) do
      ScienceTechnology.create!(science: @science, technology: @technology)
    end
  end

  test "the same pair constraint holds for the other two edges" do
    PartTechnology.create!(part: @part, technology: @technology)
    PersonScience.create!(person: @person, science: @science)

    assert_raises(ActiveRecord::RecordNotUnique) do
      PartTechnology.create!(part: @part, technology: @technology)
    end
    assert_raises(ActiveRecord::RecordNotUnique) do
      PersonScience.create!(person: @person, science: @science)
    end
  end

  # Every detail must be attributable to a processing run — the column is NOT
  # NULL by design, so a detail with no report is a validation failure, not a
  # row with a hole in it.
  test "a relationship detail cannot exist without a processing report" do
    edge = ScienceTechnology.create!(science: @science, technology: @technology)

    assert_raises(ActiveRecord::RecordInvalid) do
      ScienceTechnologyDetail.create!(science_technology: edge, as_of: Time.current)
    end
  end

  test "an entity detail cannot exist without a processing report or a name" do
    assert_raises(ActiveRecord::RecordInvalid) do
      ScienceDetail.create!(science: @science, name: "Ferromagnetism")
    end

    assert_raises(ActiveRecord::RecordInvalid) do
      TechnologyDetail.create!(technology: @technology, source_processing_report: @report)
    end
  end

  test "the current pointer is what was assigned, not the newest row" do
    edge = ScienceTechnology.create!(science: @science, technology: @technology)
    older = ScienceTechnologyDetail.create!(science_technology: edge, source_processing_report: @report,
                                            as_of: 2.years.ago, confidence_tenths: 500)
    ScienceTechnologyDetail.create!(science_technology: edge, source_processing_report: @report,
                                    as_of: Time.current, confidence_tenths: 900)

    edge.update!(current_detail: older)

    assert_equal older, edge.reload.current_detail
    assert_equal 2, edge.science_technology_details.count
  end

  test "an entity reaches the other side through the relationship" do
    ScienceTechnology.create!(science: @science, technology: @technology)
    PartTechnology.create!(part: @part, technology: @technology)
    PersonScience.create!(person: @person, science: @science)

    assert_equal [ @technology ], @science.technologies.to_a
    assert_equal [ @science ], @technology.sciences.to_a
    assert_equal [ @technology ], @part.technologies.to_a
    assert_equal [ @part ], @technology.parts.to_a
    assert_equal [ @science ], @person.sciences.to_a
    assert_equal [ @person ], @science.people.to_a
  end

  # Destroying the report must not leave a detail with a null provenance FK,
  # which the column forbids — the cascade is :destroy for exactly that reason.
  test "destroying a report takes its details with it" do
    edge = ScienceTechnology.create!(science: @science, technology: @technology)
    ScienceTechnologyDetail.create!(science_technology: edge, source_processing_report: @report,
                                    as_of: Time.current, confidence_tenths: 900)
    ScienceDetail.create!(science: @science, source_processing_report: @report,
                          name: "Ferromagnetism", as_of: Time.current, confidence_tenths: 900)

    assert_difference [ "ScienceTechnologyDetail.count", "ScienceDetail.count" ], -1 do
      @report.destroy!
    end
  end
end
