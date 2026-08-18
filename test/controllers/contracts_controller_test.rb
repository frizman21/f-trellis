require "test_helper"

class ContractsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @report = SourceProcessingReport.create!(source: sources(:one),
                                             skill_revision: skill_revisions(:promoted_1),
                                             status: "processing")
    @development = ContractType.create!(name: "Development Contract #{SecureRandom.hex(3)}")

    @contract = Contract.create!
    @current = ContractDetail.create!(
      contract: @contract, source_processing_report: @report,
      identifier: "FA2541-26-C-B007",
      title: "Compact Stored Propellant Propulsion System",
      value_usd: 1_699_936.24,
      start_date: Date.new(2026, 1, 23), end_date: Date.new(2027, 7, 22),
      as_of: Time.zone.parse("2026-01-23"), confidence_tenths: 950,
      additional_attributes: { "phase" => "Phase II", "program" => "SBIR" }
    )
    @current.contract_types = [ @development ]
    @contract.update!(current_detail: @current)
  end

  test "the index lists contracts with a count, their title and their types" do
    get contracts_path

    assert_response :success
    assert_match "FA2541-26-C-B007", @response.body
    assert_match "Compact Stored Propellant Propulsion System", @response.body
    assert_match "Showing", @response.body
    assert_match @development.name, @response.body
  end

  test "searching the contract number shows what it matched on" do
    get contracts_path, params: { q: "fa2541" }

    assert_response :success
    assert_match "Matched on", @response.body
    assert_match "Identifier: FA2541-26-C-B007", @response.body
  end

  test "searching the title matches" do
    get contracts_path, params: { q: "stored propellant" }

    assert_response :success
    assert_match "Title: Compact Stored Propellant", @response.body
  end

  test "searching a property-bag value matches and names the key" do
    get contracts_path, params: { q: "SBIR" }

    assert_response :success
    assert_match "Program: SBIR", @response.body
  end

  test "a query matching nothing says so rather than rendering an empty table" do
    get contracts_path, params: { q: "no-such-contract" }

    assert_response :success
    assert_match "No contracts matched", @response.body
  end

  test "the show page reads the current detail, including value and term" do
    get contract_path(@contract)

    assert_response :success
    assert_match "FA2541-26-C-B007", @response.body
    assert_match "Compact Stored Propellant Propulsion System", @response.body
    assert_match "$1,699,936.24", @response.body
    assert_match "2026-01-23", @response.body
    assert_match "2027-07-22", @response.body
    assert_match "95.0%", @response.body
    assert_match @development.name, @response.body
  end

  # A start with no end is an open contract, not missing data, and the page has
  # to be able to tell the reader which it is looking at.
  test "a contract with no end date says so rather than rendering a half range" do
    @current.update!(end_date: nil)

    get contract_path(@contract)

    assert_response :success
    assert_match "no end date recorded", @response.body
  end

  test "the show page lists prior details and leaves the current one out of them" do
    prior = ContractDetail.create!(
      contract: @contract, source_processing_report: @report,
      identifier: "FA2541-26-C-B007", title: "Earlier title", value_usd: 900_000,
      as_of: Time.zone.parse("2025-06-25"), confidence_tenths: 600
    )

    get contract_path(@contract)

    assert_response :success
    assert_match "Prior details", @response.body
    assert_match prior.title, @response.body
    assert_select "td", text: "60.0%"
  end

  test "the show page names all four of its relationships even when there are none" do
    get contract_path(@contract)

    assert_response :success
    assert_match "No organizations recorded for this contract.", @response.body
    assert_match "No people recorded for this contract.", @response.body
    assert_match "No technologies recorded for this contract.", @response.body
    assert_match "No parts recorded for this contract.", @response.body
  end

  test "the show page lists every party to the contract" do
    org = Organization.create!
    org.update!(current_detail: OrganizationDetail.create!(
      organization: org, source_processing_report: @report, name: "Busek Co Inc",
      as_of: Time.current, confidence_tenths: 900
    ))
    person = Person.create!
    person.update!(current_detail: PersonDetail.create!(
      person: person, source_processing_report: @report, first_name: "James", last_name: "Szabo",
      as_of: Time.current, confidence_tenths: 950
    ))
    technology = Technology.create!
    technology.update!(current_detail: TechnologyDetail.create!(
      technology: technology, source_processing_report: @report, name: "Hall Thruster",
      as_of: Time.current, confidence_tenths: 900
    ))
    part = Part.create!
    part.update!(current_detail: PartDetail.create!(
      part: part, source_processing_report: @report, name: "Propellant Feed System",
      as_of: Time.current, confidence_tenths: 900
    ))

    awardee = ContractOrganizationType.create!(name: "Awardee #{SecureRandom.hex(3)}")
    pi      = ContractPersonType.create!(name: "Principal Investigator #{SecureRandom.hex(3)}")
    develop = ContractTechnologyType.create!(name: "Develop #{SecureRandom.hex(3)}")
    deliver = ContractPartType.create!(name: "Deliverable #{SecureRandom.hex(3)}")

    co = ContractOrganization.create!(contract: @contract, organization: org)
    co.update!(current_detail: ContractOrganizationDetail.create!(
      contract_organization: co, source_processing_report: @report,
      as_of: Time.current, confidence_tenths: 950
    ).tap { |d| d.contract_organization_types = [ awardee ] })

    cp = ContractPerson.create!(contract: @contract, person: person)
    cp.update!(current_detail: ContractPersonDetail.create!(
      contract_person: cp, source_processing_report: @report,
      as_of: Time.current, confidence_tenths: 950
    ).tap { |d| d.contract_person_types = [ pi ] })

    ct = ContractTechnology.create!(contract: @contract, technology: technology)
    ct.update!(current_detail: ContractTechnologyDetail.create!(
      contract_technology: ct, source_processing_report: @report,
      as_of: Time.current, confidence_tenths: 900
    ).tap { |d| d.contract_technology_types = [ develop ] })

    cpart = ContractPart.create!(contract: @contract, part: part)
    cpart.update!(current_detail: ContractPartDetail.create!(
      contract_part: cpart, source_processing_report: @report,
      as_of: Time.current, confidence_tenths: 900
    ).tap { |d| d.contract_part_types = [ deliver ] })

    get contract_path(@contract)

    assert_response :success
    assert_match "Busek Co Inc", @response.body
    assert_match "James Szabo", @response.body
    assert_match "Hall Thruster", @response.body
    assert_match "Propellant Feed System", @response.body
    assert_match awardee.name, @response.body
    assert_match contract_organization_path(co), @response.body
    assert_match contract_person_path(cp), @response.body
    assert_match contract_technology_path(ct), @response.body
    assert_match contract_part_path(cpart), @response.body
  end
end
