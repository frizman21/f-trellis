require "test_helper"

class SciencesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @report = SourceProcessingReport.create!(source: sources(:one),
                                             skill_revision: skill_revisions(:promoted_1),
                                             status: "processing")
    @discipline = ScienceType.create!(name: "Discipline #{SecureRandom.hex(3)}")

    @science = Science.create!
    @current = ScienceDetail.create!(
      science: @science, source_processing_report: @report,
      name: "Magnetohydrodynamics",
      summary: "The flow of electrically conducting fluids in a magnetic field.",
      as_of: Time.zone.parse("1962-01-01"), confidence_tenths: 900,
      additional_attributes: { "parent_field" => "Plasma Physics" }
    )
    @current.science_types = [ @discipline ]
    @science.update!(current_detail: @current)
  end

  test "the index lists sciences with a count and their types" do
    get sciences_path

    assert_response :success
    assert_match "Magnetohydrodynamics", @response.body
    assert_match "Showing", @response.body
    assert_match @discipline.name, @response.body
  end

  test "searching a name shows what it matched on rather than the types" do
    get sciences_path, params: { q: "magnetohydro" }

    assert_response :success
    assert_match "Matched on", @response.body
    assert_match "Name: Magnetohydrodynamics", @response.body
  end

  # The summary is a typed column precisely so it is searchable; a bag-only
  # search would miss the one sentence that says what a field is about.
  test "searching a summary matches" do
    get sciences_path, params: { q: "conducting fluids" }

    assert_response :success
    assert_match "Magnetohydrodynamics", @response.body
    assert_match "Summary:", @response.body
  end

  test "searching a property-bag value matches and names the key" do
    get sciences_path, params: { q: "Plasma" }

    assert_response :success
    assert_match "Parent field: Plasma Physics", @response.body
  end

  test "a query matching nothing says so rather than rendering an empty table" do
    get sciences_path, params: { q: "no-such-science" }

    assert_response :success
    assert_match "No sciences matched", @response.body
  end

  test "the show page reads the current detail" do
    get science_path(@science)

    assert_response :success
    assert_match "Magnetohydrodynamics", @response.body
    assert_match "The flow of electrically conducting fluids", @response.body
    assert_match "90.0%", @response.body
    assert_match @discipline.name, @response.body
    assert_match "Parent field", @response.body
  end

  test "the show page lists prior details and leaves the current one out of them" do
    prior = ScienceDetail.create!(
      science: @science, source_processing_report: @report,
      name: "Magneto-fluid dynamics", summary: "An earlier name for the same field.",
      as_of: Time.zone.parse("1937-01-01"), confidence_tenths: 600
    )

    get science_path(@science)

    assert_response :success
    assert_match "Prior details", @response.body
    assert_match prior.name, @response.body
    assert_select "td", text: "60.0%"
  end

  # The heading renders with no rows on purpose: "no technologies recorded" and
  # "this page does not show technologies" are different facts.
  test "the show page names its relationships even when there are none" do
    get science_path(@science)

    assert_response :success
    assert_match "No technologies recorded for this science.", @response.body
    assert_match "No people recorded for this science.", @response.body
  end

  test "the show page lists related technologies and people" do
    technology = Technology.create!
    tech_detail = TechnologyDetail.create!(technology: technology, source_processing_report: @report,
                                           name: "Magnetoplasmadynamic Thruster",
                                           as_of: Time.current, confidence_tenths: 900)
    technology.update!(current_detail: tech_detail)

    st_type = ScienceTechnologyType.create!(name: "Application #{SecureRandom.hex(3)}")
    edge = ScienceTechnology.create!(science: @science, technology: technology)
    st_detail = ScienceTechnologyDetail.create!(science_technology: edge, source_processing_report: @report,
                                                as_of: Time.current, confidence_tenths: 850)
    st_detail.science_technology_types = [ st_type ]
    edge.update!(current_detail: st_detail)

    person = Person.create!
    person_detail = PersonDetail.create!(person: person, source_processing_report: @report,
                                         first_name: "Hannes", last_name: "Alfven",
                                         as_of: Time.current, confidence_tenths: 1000)
    person.update!(current_detail: person_detail)

    ps_type = PersonScienceType.create!(name: "Researcher #{SecureRandom.hex(3)}")
    ps_edge = PersonScience.create!(person: person, science: @science)
    ps_detail = PersonScienceDetail.create!(person_science: ps_edge, source_processing_report: @report,
                                            as_of: Time.current, confidence_tenths: 900)
    ps_detail.person_science_types = [ ps_type ]
    ps_edge.update!(current_detail: ps_detail)

    get science_path(@science)

    assert_response :success
    assert_match "Magnetoplasmadynamic Thruster", @response.body
    assert_match st_type.name, @response.body
    assert_match "Hannes Alfven", @response.body
    assert_match ps_type.name, @response.body
    assert_match science_technology_path(edge), @response.body
    assert_match person_science_path(ps_edge), @response.body
  end
end
