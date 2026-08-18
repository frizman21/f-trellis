require "test_helper"

# The writing tools a run over an award page calls.
class ContractToolsTest < ActiveSupport::TestCase
  setup do
    @report = SourceProcessingReport.create!(source: sources(:one),
                                             skill_revision: skill_revisions(:promoted_1),
                                             status: "processing")
    @contracts = UpsertContractTool.new(@report)

    @development = ContractType.find_or_create_by!(name: "Development Contract")
    @awardee = ContractOrganizationType.find_or_create_by!(name: "Awardee")
    @pi = ContractPersonType.find_or_create_by!(name: "Principal Investigator")
    @develop = ContractTechnologyType.find_or_create_by!(name: "Develop")
    @deliverable = ContractPartType.find_or_create_by!(name: "Deliverable")
    @developer = OrganizationTechnologyType.find_or_create_by!(name: "Developer")
  end

  # --- upsert_contract ------------------------------------------------------

  test "a contract is created with its typed fields, types and current pointer" do
    result = @contracts.execute(contracts: [
      { identifier: "FA2541-26-C-B007", title: "Compact Stored Propellant Propulsion System",
        value_usd: "1699936.24", start_date: "2026-01-23", end_date: "2027-07-22",
        contract_types: [ "Development Contract" ], confidence_tenths: 950,
        additional_attributes: [ { key: "phase", value: "Phase II" } ] }
    ])[:results].first

    assert result[:created]
    detail = Contract.find(result[:contract_id]).current_detail

    assert_equal result[:detail_id], detail.id
    assert_equal "FA2541-26-C-B007", detail.identifier
    assert_equal "Compact Stored Propellant Propulsion System", detail.title
    assert_equal BigDecimal("1699936.24"), detail.value_usd
    assert_equal Date.new(2026, 1, 23), detail.start_date
    assert_equal Date.new(2027, 7, 22), detail.end_date
    assert_equal [ @development ], detail.contract_types.to_a
    assert_equal({ "phase" => "Phase II" }, detail.additional_attributes)
    assert_equal @report, detail.source_processing_report
  end

  test "a second call on the same identifier reuses the contract and advances the pointer" do
    first = @contracts.execute(contracts: [ { identifier: "DE-AR0001963" } ])[:results].first
    second = @contracts.execute(contracts: [ { identifier: "de-ar0001963" } ])[:results].first

    assert first[:created]
    assert_not second[:created]
    assert_equal first[:contract_id], second[:contract_id]

    contract = Contract.find(first[:contract_id])
    assert_equal 2, contract.contract_details.count
    assert_equal second[:detail_id], contract.current_detail_id
  end

  # A page writes money the way a person reads it, not the way a column stores it.
  test "an award value survives the punctuation a page puts around it" do
    result = @contracts.execute(contracts: [
      { identifier: "N00014-21-C-0001", value_usd: "$1,699,936.24" }
    ])[:results].first

    assert_equal BigDecimal("1699936.24"), ContractDetail.find(result[:detail_id]).value_usd
  end

  test "a value with no number in it is left blank rather than stored as zero" do
    result = @contracts.execute(contracts: [
      { identifier: "N00014-21-C-0002", value_usd: "undisclosed" }
    ])[:results].first

    assert_nil ContractDetail.find(result[:detail_id]).value_usd
  end

  test "an unparseable date is left blank rather than raising" do
    result = @contracts.execute(contracts: [
      { identifier: "N00014-21-C-0003", start_date: "sometime in the spring" }
    ])[:results].first

    assert_nil result[:error]
    assert_nil ContractDetail.find(result[:detail_id]).start_date
  end

  test "confidence is clamped and defaulted" do
    over = @contracts.execute(contracts: [ { identifier: "A-1", confidence_tenths: 5000 } ])[:results].first
    under = @contracts.execute(contracts: [ { identifier: "A-2", confidence_tenths: -20 } ])[:results].first
    absent = @contracts.execute(contracts: [ { identifier: "A-3" } ])[:results].first

    assert_equal 1000, ContractDetail.find(over[:detail_id]).confidence_tenths
    assert_equal 0, ContractDetail.find(under[:detail_id]).confidence_tenths
    assert_equal 800, ContractDetail.find(absent[:detail_id]).confidence_tenths
  end

  test "an unconfigured type name is reported, and the entry is still recorded" do
    result = @contracts.execute(contracts: [
      { identifier: "A-4", contract_types: [ "Development Contract", "Handshake" ] }
    ])[:results].first

    assert_equal [ "contract type 'Handshake' is not configured" ], result[:type_errors]
    assert_equal [ @development ], ContractDetail.find(result[:detail_id]).contract_types.to_a
  end

  test "a blank identifier returns an error in its slot and writes nothing" do
    assert_no_difference [ "Contract.count", "ContractDetail.count" ] do
      assert_equal "identifier is required",
                   @contracts.execute(contracts: [ { identifier: "  " } ])[:results].first[:error]
    end
  end

  test "an empty array is refused" do
    assert_equal "contracts must be a non-empty array", @contracts.execute(contracts: [])[:error]
  end

  # --- the link tools -------------------------------------------------------

  def contract_id
    @contracts.execute(contracts: [ { identifier: "FA2541-26-C-B007" } ])[:results].first[:contract_id]
  end

  def technology_id
    UpsertTechnologyTool.new(@report)
      .execute(technologies: [ { name: "Hall Thruster" } ])[:results].first[:technology_id]
  end

  def organization_id
    UpsertOrganizationTool.new(@report)
      .execute(organizations: [ { name: "Busek Co Inc" } ])[:results].first[:organization_id]
  end

  test "a contract links to the organization it is with" do
    result = LinkContractOrganizationTool.new(@report).execute(
      contract_id: contract_id, organization_id: organization_id, type: "Awardee",
      as_of: "2026-01-23T00:00:00Z", confidence_tenths: 950,
      additional_attributes: { "role" => "prime", "nested" => { "no" => "thanks" } }
    )

    edge = ContractOrganization.find(result[:contract_organization_id])
    detail = edge.current_detail

    assert_equal [ @awardee ], detail.contract_organization_types.to_a
    assert_equal 950, detail.confidence_tenths
    assert_equal 2026, detail.as_of.year
    assert_equal({ "role" => "prime" }, detail.additional_attributes)
  end

  test "a contract links to its principal investigator, its technology and its deliverable" do
    cid = contract_id
    person_id = UpsertPersonTool.new(@report)
      .execute(people: [ { first_name: "James", last_name: "Szabo" } ])[:results].first[:person_id]
    part_id = UpsertPartTool.new(@report).execute(parts: [
      { name: "Propellant Feed System",
        part_types: [ PartType.find_or_create_by!(name: "Physical Part").name ] }
    ])[:results].first[:part_id]

    person_link = LinkContractPersonTool.new(@report)
      .execute(contract_id: cid, person_id: person_id, type: "Principal Investigator")
    tech_link = LinkContractTechnologyTool.new(@report)
      .execute(contract_id: cid, technology_id: technology_id, type: "Develop")
    part_link = LinkContractPartTool.new(@report)
      .execute(contract_id: cid, part_id: part_id, type: "Deliverable")

    assert_equal [ @pi ], ContractPerson.find(person_link[:contract_person_id]).current_detail.contract_person_types.to_a
    assert_equal [ @develop ], ContractTechnology.find(tech_link[:contract_technology_id]).current_detail.contract_technology_types.to_a
    assert_equal [ @deliverable ], ContractPart.find(part_link[:contract_part_id]).current_detail.contract_part_types.to_a

    contract = Contract.find(cid)
    assert_equal 1, contract.people.count
    assert_equal 1, contract.technologies.count
    assert_equal 1, contract.parts.count
  end

  # The edge this change exists for: a technology reaching its organization
  # without a contract in the way.
  test "an organization links directly to a technology" do
    org_id = organization_id
    tech_id = technology_id

    result = LinkOrganizationTechnologyTool.new(@report).execute(
      organization_id: org_id, technology_id: tech_id, type: "Developer",
      confidence_tenths: 900, additional_attributes: { "since" => "2026" }
    )

    edge = OrganizationTechnology.find(result[:organization_technology_id])

    assert_equal [ @developer ], edge.current_detail.organization_technology_types.to_a
    assert_equal [ Organization.find(org_id) ], Technology.find(tech_id).organizations.to_a
  end

  test "linking the same pair twice adds a detail rather than a second edge" do
    cid = contract_id
    tid = technology_id
    tool = LinkContractTechnologyTool.new(@report)

    first = tool.execute(contract_id: cid, technology_id: tid, type: "Develop")
    second = tool.execute(contract_id: cid, technology_id: tid, type: "Develop")

    assert_equal first[:contract_technology_id], second[:contract_technology_id]
    edge = ContractTechnology.find(first[:contract_technology_id])
    assert_equal 2, edge.contract_technology_details.count
    assert_equal second[:detail_id], edge.current_detail_id
  end

  test "an id the tool never issued is refused and writes nothing" do
    assert_no_difference "ContractTechnology.count" do
      assert_equal "no technology #999999",
                   LinkContractTechnologyTool.new(@report)
                     .execute(contract_id: contract_id, technology_id: 999_999, type: "Develop")[:error]
    end
  end

  test "an unconfigured relationship type is refused and writes nothing" do
    assert_no_difference "OrganizationTechnology.count" do
      assert_equal "OrganizationTechnologyType 'Dabbler' is not configured",
                   LinkOrganizationTechnologyTool.new(@report)
                     .execute(organization_id: organization_id, technology_id: technology_id,
                              type: "Dabbler")[:error]
    end
  end
end
