require "test_helper"

# The reason issue #185 exists: a Technology page could not say who was building
# the thing. These assert the page answers that now, and — the part that matters
# — that it answers it from real edges rather than by association through a
# shared science.
class TechnologyAssociationsTest < ActionDispatch::IntegrationTest
  setup do
    @report = SourceProcessingReport.create!(source: sources(:one),
                                             skill_revision: skill_revisions(:promoted_1),
                                             status: "processing")
    @optics = science("Optics")

    # Two unrelated projects that happen to share a science, which is the exact
    # shape that produced the false positive in the award data.
    @eye_sensor = technology("Implantable Optical Pressure Sensor")
    @fruit_grader = technology("Laser-Based Maturity Sensing")
    [ @eye_sensor, @fruit_grader ].each { |t| link_science(t, @optics) }

    @brockman = organization("Brockman-Hastings LLC")
    @astleford = organization("Astleford Inc")
    @hastings = person("Jeffrey", "Hastings")
    @astleford_jr = person("John", "Astleford")
  end

  test "a technology lists the organizations linked directly to it" do
    developer = OrganizationTechnologyType.create!(name: "Developer #{SecureRandom.hex(3)}")
    link_organization(@brockman, @eye_sensor, developer)

    get technology_path(@eye_sensor)

    assert_response :success
    assert_match "Brockman-Hastings LLC", @response.body
    assert_match developer.name, @response.body
  end

  test "a technology lists the contracts funding it, and the contract names the company" do
    awardee = ContractOrganizationType.create!(name: "Awardee #{SecureRandom.hex(3)}")
    develop = ContractTechnologyType.create!(name: "Develop #{SecureRandom.hex(3)}")
    contract = contract_for("NIH-EY-0001", "Implantable IOP sensor")

    link_contract_organization(contract, @brockman, awardee)
    link_contract_technology(contract, @eye_sensor, develop)

    get technology_path(@eye_sensor)

    assert_response :success
    assert_match "NIH-EY-0001", @response.body
    assert_match develop.name, @response.body

    get contract_path(contract)

    assert_response :success
    assert_match "Brockman-Hastings LLC", @response.body
  end

  # The regression this whole change exists to prevent. Both technologies rest
  # on Optics and both PIs research Optics, but they are different projects
  # nineteen years apart, and neither page may claim the other's people or
  # companies.
  test "two technologies sharing a science do not leak each other's people or companies" do
    developer = OrganizationTechnologyType.create!(name: "Developer #{SecureRandom.hex(3)}")
    researcher = PersonScienceType.create!(name: "Researcher #{SecureRandom.hex(3)}")

    link_organization(@brockman, @eye_sensor, developer)
    link_organization(@astleford, @fruit_grader, developer)
    link_person_science(@hastings, @optics, researcher)
    link_person_science(@astleford_jr, @optics, researcher)

    get technology_path(@fruit_grader)

    assert_response :success
    assert_match "Astleford Inc", @response.body
    assert_no_match(/Brockman-Hastings/, @response.body,
                    "a shared science must not carry another project's company onto this page")
    assert_no_match(/Jeffrey Hastings/, @response.body,
                    "a shared science must not carry another project's person onto this page")
  end

  test "the association is reciprocal: an organization lists its technologies" do
    developer = OrganizationTechnologyType.create!(name: "Developer #{SecureRandom.hex(3)}")
    link_organization(@brockman, @eye_sensor, developer)

    get organization_path(@brockman)

    assert_response :success
    assert_match "Implantable Optical Pressure Sensor", @response.body
  end

  test "a technology with nobody behind it says so rather than rendering nothing" do
    get technology_path(@eye_sensor)

    assert_response :success
    assert_match "No contracts recorded for this technology.", @response.body
    assert_match "No organizations recorded for this technology.", @response.body
  end

  private

  def science(name)
    Science.create!.tap do |s|
      s.update!(current_detail: ScienceDetail.create!(
        science: s, source_processing_report: @report, name: name,
        as_of: Time.current, confidence_tenths: 900
      ))
    end
  end

  def technology(name)
    Technology.create!.tap do |t|
      t.update!(current_detail: TechnologyDetail.create!(
        technology: t, source_processing_report: @report, name: name,
        as_of: Time.current, confidence_tenths: 900
      ))
    end
  end

  def organization(name)
    Organization.create!.tap do |o|
      o.update!(current_detail: OrganizationDetail.create!(
        organization: o, source_processing_report: @report, name: name,
        as_of: Time.current, confidence_tenths: 900
      ))
    end
  end

  def person(first, last)
    Person.create!.tap do |p|
      p.update!(current_detail: PersonDetail.create!(
        person: p, source_processing_report: @report, first_name: first, last_name: last,
        as_of: Time.current, confidence_tenths: 950
      ))
    end
  end

  def contract_for(identifier, title)
    Contract.create!.tap do |c|
      c.update!(current_detail: ContractDetail.create!(
        contract: c, source_processing_report: @report, identifier: identifier, title: title,
        as_of: Time.current, confidence_tenths: 900
      ))
    end
  end

  def link_science(technology, science)
    type = ScienceTechnologyType.find_or_create_by!(name: "Application")
    edge = ScienceTechnology.create!(science: science, technology: technology)
    edge.update!(current_detail: ScienceTechnologyDetail.create!(
      science_technology: edge, source_processing_report: @report,
      as_of: Time.current, confidence_tenths: 800
    ).tap { |d| d.science_technology_types = [ type ] })
  end

  def link_organization(organization, technology, type)
    edge = OrganizationTechnology.create!(organization: organization, technology: technology)
    edge.update!(current_detail: OrganizationTechnologyDetail.create!(
      organization_technology: edge, source_processing_report: @report,
      as_of: Time.current, confidence_tenths: 900
    ).tap { |d| d.organization_technology_types = [ type ] })
  end

  def link_person_science(person, science, type)
    edge = PersonScience.create!(person: person, science: science)
    edge.update!(current_detail: PersonScienceDetail.create!(
      person_science: edge, source_processing_report: @report,
      as_of: Time.current, confidence_tenths: 900
    ).tap { |d| d.person_science_types = [ type ] })
  end

  def link_contract_organization(contract, organization, type)
    edge = ContractOrganization.create!(contract: contract, organization: organization)
    edge.update!(current_detail: ContractOrganizationDetail.create!(
      contract_organization: edge, source_processing_report: @report,
      as_of: Time.current, confidence_tenths: 950
    ).tap { |d| d.contract_organization_types = [ type ] })
  end

  def link_contract_technology(contract, technology, type)
    edge = ContractTechnology.create!(contract: contract, technology: technology)
    edge.update!(current_detail: ContractTechnologyDetail.create!(
      contract_technology: edge, source_processing_report: @report,
      as_of: Time.current, confidence_tenths: 900
    ).tap { |d| d.contract_technology_types = [ type ] })
  end
end
