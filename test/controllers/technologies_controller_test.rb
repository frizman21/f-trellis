require "test_helper"

class TechnologiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @report = SourceProcessingReport.create!(source: sources(:one),
                                             skill_revision: skill_revisions(:promoted_1),
                                             status: "processing")
    @device = TechnologyType.create!(name: "Device #{SecureRandom.hex(3)}")

    @technology = Technology.create!
    @current = TechnologyDetail.create!(
      technology: @technology, source_processing_report: @report,
      name: "Core Rope Memory",
      summary: "Read-only storage woven by hand from magnetic cores.",
      as_of: Time.zone.parse("1964-01-01"), confidence_tenths: 900,
      additional_attributes: { "maturity" => "flight qualified" }
    )
    @current.technology_types = [ @device ]
    @technology.update!(current_detail: @current)
  end

  test "the index lists technologies with a count and their types" do
    get technologies_path

    assert_response :success
    assert_match "Core Rope Memory", @response.body
    assert_match "Showing", @response.body
    assert_match @device.name, @response.body
  end

  test "searching a name shows what it matched on rather than the types" do
    get technologies_path, params: { q: "core rope" }

    assert_response :success
    assert_match "Matched on", @response.body
    assert_match "Name: Core Rope Memory", @response.body
  end

  test "searching a summary matches" do
    get technologies_path, params: { q: "woven by hand" }

    assert_response :success
    assert_match "Core Rope Memory", @response.body
    assert_match "Summary:", @response.body
  end

  test "searching a property-bag value matches and names the key" do
    get technologies_path, params: { q: "flight qualified" }

    assert_response :success
    assert_match "Maturity: flight qualified", @response.body
  end

  test "a query matching nothing says so rather than rendering an empty table" do
    get technologies_path, params: { q: "no-such-technology" }

    assert_response :success
    assert_match "No technologies matched", @response.body
  end

  test "the show page reads the current detail" do
    get technology_path(@technology)

    assert_response :success
    assert_match "Core Rope Memory", @response.body
    assert_match "Read-only storage woven by hand", @response.body
    assert_match "90.0%", @response.body
    assert_match @device.name, @response.body
    assert_match "Maturity", @response.body
  end

  test "the show page lists prior details and leaves the current one out of them" do
    prior = TechnologyDetail.create!(
      technology: @technology, source_processing_report: @report,
      name: "Rope Memory", summary: "An earlier name.",
      as_of: Time.zone.parse("1960-01-01"), confidence_tenths: 600
    )

    get technology_path(@technology)

    assert_response :success
    assert_match "Prior details", @response.body
    assert_match prior.name, @response.body
    assert_select "td", text: "60.0%"
  end

  test "the show page names its relationships even when there are none" do
    get technology_path(@technology)

    assert_response :success
    assert_match "No sciences recorded for this technology.", @response.body
    assert_match "No parts recorded for this technology.", @response.body
  end

  test "the show page lists related sciences and parts" do
    science = Science.create!
    science_detail = ScienceDetail.create!(science: science, source_processing_report: @report,
                                           name: "Ferromagnetism", as_of: Time.current,
                                           confidence_tenths: 900)
    science.update!(current_detail: science_detail)

    st_type = ScienceTechnologyType.create!(name: "Application #{SecureRandom.hex(3)}")
    st_edge = ScienceTechnology.create!(science: science, technology: @technology)
    st_detail = ScienceTechnologyDetail.create!(science_technology: st_edge,
                                                source_processing_report: @report,
                                                as_of: Time.current, confidence_tenths: 900)
    st_detail.science_technology_types = [ st_type ]
    st_edge.update!(current_detail: st_detail)

    part = Part.create!
    part_detail = PartDetail.create!(part: part, source_processing_report: @report,
                                     name: "AGC Memory Module", as_of: Time.current,
                                     confidence_tenths: 950)
    part.update!(current_detail: part_detail)

    pt_type = PartTechnologyType.create!(name: "Implementation #{SecureRandom.hex(3)}")
    pt_edge = PartTechnology.create!(part: part, technology: @technology)
    pt_detail = PartTechnologyDetail.create!(part_technology: pt_edge,
                                             source_processing_report: @report,
                                             as_of: Time.current, confidence_tenths: 1000)
    pt_detail.part_technology_types = [ pt_type ]
    pt_edge.update!(current_detail: pt_detail)

    get technology_path(@technology)

    assert_response :success
    assert_match "Ferromagnetism", @response.body
    assert_match st_type.name, @response.body
    assert_match "AGC Memory Module", @response.body
    assert_match pt_type.name, @response.body
    assert_match science_technology_path(st_edge), @response.body
    assert_match part_technology_path(pt_edge), @response.body
  end
end
