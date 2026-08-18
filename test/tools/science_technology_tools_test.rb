require "test_helper"

# The writing tools a run over a paper calls: two upserts and three links.
class ScienceTechnologyToolsTest < ActiveSupport::TestCase
  setup do
    @report = SourceProcessingReport.create!(source: sources(:one),
                                             skill_revision: skill_revisions(:promoted_1),
                                             status: "processing")
    @sciences = UpsertScienceTool.new(@report)
    @technologies = UpsertTechnologyTool.new(@report)

    @discipline = ScienceType.find_or_create_by!(name: "Discipline")
    @device = TechnologyType.find_or_create_by!(name: "Device")
    @application = ScienceTechnologyType.find_or_create_by!(name: "Application")
    @implementation = PartTechnologyType.find_or_create_by!(name: "Implementation")
    @researcher = PersonScienceType.find_or_create_by!(name: "Researcher")
  end

  # --- upserts --------------------------------------------------------------

  test "a science is created with its detail, summary, types and current pointer" do
    result = @sciences.execute(sciences: [
      { name: "Magnetohydrodynamics", summary: "Conducting fluids in a magnetic field.",
        science_types: [ "Discipline" ], confidence_tenths: 900,
        additional_attributes: [ { key: "parent_field", value: "Plasma Physics" } ] }
    ])[:results].first

    assert result[:created]
    science = Science.find(result[:science_id])
    detail = science.current_detail

    assert_equal result[:detail_id], detail.id
    assert_equal "Magnetohydrodynamics", detail.name
    assert_equal "Conducting fluids in a magnetic field.", detail.summary
    assert_equal 900, detail.confidence_tenths
    assert_equal [ @discipline ], detail.science_types.to_a
    assert_equal({ "parent_field" => "Plasma Physics" }, detail.additional_attributes)
    assert_equal @report, detail.source_processing_report
  end

  # The whole point of the detail pattern: a second mention of the same subject
  # adds an assertion rather than overwriting the first one.
  test "a second call on the same name reuses the entity and advances the pointer" do
    first = @sciences.execute(sciences: [ { name: "Ferromagnetism" } ])[:results].first
    second = @sciences.execute(sciences: [ { name: "ferromagnetism" } ])[:results].first

    assert first[:created]
    assert_not second[:created]
    assert_equal first[:science_id], second[:science_id]

    science = Science.find(first[:science_id])
    assert_equal 2, science.science_details.count
    assert_equal second[:detail_id], science.current_detail_id
  end

  test "a whole batch is recorded in one call" do
    results = @technologies.execute(technologies: [
      { name: "Core Rope Memory", technology_types: [ "Device" ] },
      { name: "Integrated Circuit", technology_types: [ "Device" ] }
    ])[:results]

    assert_equal 2, results.size
    assert_equal %w[Core\ Rope\ Memory Integrated\ Circuit],
                 results.map { |r| Technology.find(r[:technology_id]).current_detail.name }.sort
  end

  test "confidence is clamped and defaults rather than storing what was asked for" do
    over = @sciences.execute(sciences: [ { name: "Over", confidence_tenths: 5000 } ])[:results].first
    under = @sciences.execute(sciences: [ { name: "Under", confidence_tenths: -20 } ])[:results].first
    absent = @sciences.execute(sciences: [ { name: "Absent" } ])[:results].first

    assert_equal 1000, ScienceDetail.find(over[:detail_id]).confidence_tenths
    assert_equal 0, ScienceDetail.find(under[:detail_id]).confidence_tenths
    assert_equal 800, ScienceDetail.find(absent[:detail_id]).confidence_tenths
  end

  # The property bag is a flat map of scalars — see docs/data-model-spec.md §2a.
  test "non-scalar property-bag values are dropped rather than nested" do
    result = @sciences.execute(sciences: [
      { name: "Optics", additional_attributes: [ { key: "parent_field", value: "Physics" },
                                                 { key: "", value: "no key" } ] }
    ])[:results].first

    assert_equal({ "parent_field" => "Physics" }, ScienceDetail.find(result[:detail_id]).additional_attributes)
  end

  # A model naming a type that does not exist has made a claim the taxonomy
  # cannot hold, and it should hear about it rather than have it vanish.
  test "an unconfigured type name is reported, and the entry is still recorded" do
    result = @sciences.execute(sciences: [
      { name: "Alchemy", science_types: [ "Discipline", "Sorcery" ] }
    ])[:results].first

    assert_equal [ "science type 'Sorcery' is not configured" ], result[:type_errors]
    assert_equal [ @discipline ], ScienceDetail.find(result[:detail_id]).science_types.to_a
  end

  test "a blank name returns an error in its slot and writes nothing" do
    assert_no_difference [ "Science.count", "ScienceDetail.count" ] do
      result = @sciences.execute(sciences: [ { name: "  " } ])[:results].first

      assert_equal "name is required", result[:error]
    end
  end

  test "an empty array is refused" do
    assert_equal "sciences must be a non-empty array", @sciences.execute(sciences: [])[:error]
    assert_equal "technologies must be a non-empty array", @technologies.execute(technologies: [])[:error]
  end

  # --- links ----------------------------------------------------------------

  def science_and_technology
    [ @sciences.execute(sciences: [ { name: "Ferromagnetism" } ])[:results].first[:science_id],
      @technologies.execute(technologies: [ { name: "Core Rope Memory" } ])[:results].first[:technology_id] ]
  end

  test "linking a science to a technology creates the edge, the detail and the pointer" do
    science_id, technology_id = science_and_technology

    result = LinkScienceTechnologyTool.new(@report).execute(
      science_id: science_id, technology_id: technology_id, type: "Application",
      as_of: "1964-01-01T00:00:00Z", confidence_tenths: 950,
      additional_attributes: { "since" => "1964", "nested" => { "no" => "thanks" } }
    )

    edge = ScienceTechnology.find(result[:science_technology_id])
    detail = edge.current_detail

    assert_equal detail.id, result[:detail_id]
    assert_equal [ @application ], detail.science_technology_types.to_a
    assert_equal 950, detail.confidence_tenths
    assert_equal 1964, detail.as_of.year
    assert_equal({ "since" => "1964" }, detail.additional_attributes)
    assert_equal @report, detail.source_processing_report
  end

  # One edge per pair — a second mention adds a detail to the edge that exists.
  test "linking the same pair twice adds a detail rather than a second edge" do
    science_id, technology_id = science_and_technology
    tool = LinkScienceTechnologyTool.new(@report)

    first = tool.execute(science_id: science_id, technology_id: technology_id, type: "Application")
    second = tool.execute(science_id: science_id, technology_id: technology_id, type: "Application")

    assert_equal first[:science_technology_id], second[:science_technology_id]
    edge = ScienceTechnology.find(first[:science_technology_id])
    assert_equal 2, edge.science_technology_details.count
    assert_equal second[:detail_id], edge.current_detail_id
  end

  test "an id the tool never issued is refused and writes nothing" do
    science_id, = science_and_technology

    assert_no_difference "ScienceTechnology.count" do
      result = LinkScienceTechnologyTool.new(@report).execute(
        science_id: science_id, technology_id: 999_999, type: "Application"
      )

      assert_equal "no technology #999999", result[:error]
    end
  end

  test "an unconfigured relationship type is refused and writes nothing" do
    science_id, technology_id = science_and_technology

    assert_no_difference "ScienceTechnology.count" do
      result = LinkScienceTechnologyTool.new(@report).execute(
        science_id: science_id, technology_id: technology_id, type: "Sorcery"
      )

      assert_equal "ScienceTechnologyType 'Sorcery' is not configured", result[:error]
    end
  end

  test "a part links to a technology" do
    part = Part.create!
    PartDetail.create!(part: part, source_processing_report: @report, name: "AGC Memory Module",
                       as_of: Time.current, confidence_tenths: 950)
    _, technology_id = science_and_technology

    result = LinkPartTechnologyTool.new(@report).execute(
      part_id: part.id, technology_id: technology_id, type: "Implementation"
    )

    edge = PartTechnology.find(result[:part_technology_id])

    assert_equal part, edge.part
    assert_equal [ @implementation ], edge.current_detail.part_technology_types.to_a
  end

  test "a person links to a science" do
    person = Person.create!
    PersonDetail.create!(person: person, source_processing_report: @report,
                         first_name: "Hannes", last_name: "Alfven",
                         as_of: Time.current, confidence_tenths: 1000)
    science_id, = science_and_technology

    result = LinkPersonScienceTool.new(@report).execute(
      person_id: person.id, science_id: science_id, type: "Researcher"
    )

    edge = PersonScience.find(result[:person_science_id])

    assert_equal person, edge.person
    assert_equal [ @researcher ], edge.current_detail.person_science_types.to_a
  end
end
