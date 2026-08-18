require "test_helper"

# The invariants the Contract entity and its four edges rest on, plus the direct
# organization-to-technology edge added alongside them.
class ContractTest < ActiveSupport::TestCase
  setup do
    @report = SourceProcessingReport.create!(source: sources(:one),
                                             skill_revision: skill_revisions(:promoted_1),
                                             status: "processing")
    @contract = Contract.create!
    @organization = Organization.create!
    @person = Person.create!
    @technology = Technology.create!
    @part = Part.create!
  end

  test "a detail needs an identifier and a processing report" do
    assert_raises(ActiveRecord::RecordInvalid) do
      ContractDetail.create!(contract: @contract, source_processing_report: @report)
    end

    assert_raises(ActiveRecord::RecordInvalid) do
      ContractDetail.create!(contract: @contract, identifier: "DE-AR0001963")
    end
  end

  test "a pair may only be connected once, on every one of the five edges" do
    ContractOrganization.create!(contract: @contract, organization: @organization)
    ContractPerson.create!(contract: @contract, person: @person)
    ContractTechnology.create!(contract: @contract, technology: @technology)
    ContractPart.create!(contract: @contract, part: @part)
    OrganizationTechnology.create!(organization: @organization, technology: @technology)

    assert_raises(ActiveRecord::RecordNotUnique) { ContractOrganization.create!(contract: @contract, organization: @organization) }
    assert_raises(ActiveRecord::RecordNotUnique) { ContractPerson.create!(contract: @contract, person: @person) }
    assert_raises(ActiveRecord::RecordNotUnique) { ContractTechnology.create!(contract: @contract, technology: @technology) }
    assert_raises(ActiveRecord::RecordNotUnique) { ContractPart.create!(contract: @contract, part: @part) }
    assert_raises(ActiveRecord::RecordNotUnique) { OrganizationTechnology.create!(organization: @organization, technology: @technology) }
  end

  test "a relationship detail cannot exist without a processing report" do
    edge = ContractTechnology.create!(contract: @contract, technology: @technology)

    assert_raises(ActiveRecord::RecordInvalid) do
      ContractTechnologyDetail.create!(contract_technology: edge, as_of: Time.current)
    end
  end

  # ContractPerson pluralises to contract_people, the same Rails inflection
  # PersonPerson already hits. Asserted because a wrong table name here fails at
  # query time rather than at load time.
  test "every edge resolves through has_many in both directions" do
    ContractOrganization.create!(contract: @contract, organization: @organization)
    ContractPerson.create!(contract: @contract, person: @person)
    ContractTechnology.create!(contract: @contract, technology: @technology)
    ContractPart.create!(contract: @contract, part: @part)
    OrganizationTechnology.create!(organization: @organization, technology: @technology)

    assert_equal [ @organization ], @contract.organizations.to_a
    assert_equal [ @person ], @contract.people.to_a
    assert_equal [ @technology ], @contract.technologies.to_a
    assert_equal [ @part ], @contract.parts.to_a

    assert_equal [ @contract ], @organization.contracts.to_a
    assert_equal [ @contract ], @person.contracts.to_a
    assert_equal [ @contract ], @technology.contracts.to_a
    assert_equal [ @contract ], @part.contracts.to_a

    assert_equal [ @technology ], @organization.technologies.to_a
    assert_equal [ @organization ], @technology.organizations.to_a
  end

  test "the current pointer is what was assigned, not the newest row" do
    older = ContractDetail.create!(contract: @contract, source_processing_report: @report,
                                   identifier: "DE-AR0001963", as_of: 2.years.ago,
                                   confidence_tenths: 500)
    ContractDetail.create!(contract: @contract, source_processing_report: @report,
                           identifier: "DE-AR0001963", as_of: Time.current,
                           confidence_tenths: 900)

    @contract.update!(current_detail: older)

    assert_equal older, @contract.reload.current_detail
    assert_equal 2, @contract.contract_details.count
  end

  test "destroying a report takes its contract details with it" do
    ContractDetail.create!(contract: @contract, source_processing_report: @report,
                           identifier: "DE-AR0001963", as_of: Time.current, confidence_tenths: 900)
    edge = ContractTechnology.create!(contract: @contract, technology: @technology)
    ContractTechnologyDetail.create!(contract_technology: edge, source_processing_report: @report,
                                     as_of: Time.current, confidence_tenths: 900)

    assert_difference [ "ContractDetail.count", "ContractTechnologyDetail.count" ], -1 do
      @report.destroy!
    end
  end

  # The label is what every relationship table shows for a contract, so an
  # untitled contract must still render as something a person can read.
  test "the label falls back to the identifier when there is no title" do
    titled = ContractDetail.create!(contract: @contract, source_processing_report: @report,
                                    identifier: "DE-AR0001963", title: "Phytomining platform",
                                    as_of: Time.current, confidence_tenths: 900)
    untitled = ContractDetail.create!(contract: Contract.create!, source_processing_report: @report,
                                      identifier: "DE-AR0001984", as_of: Time.current,
                                      confidence_tenths: 900)

    assert_equal "DE-AR0001963 — Phytomining platform", titled.label
    assert_equal "DE-AR0001984", untitled.label
  end

  test "term is nil unless both ends are known" do
    open_ended = ContractDetail.create!(contract: @contract, source_processing_report: @report,
                                        identifier: "DE-AR0001963", start_date: Date.new(2026, 1, 23),
                                        as_of: Time.current, confidence_tenths: 900)
    assert_nil open_ended.term

    open_ended.update!(end_date: Date.new(2027, 7, 22))
    assert_equal Date.new(2026, 1, 23)..Date.new(2027, 7, 22), open_ended.reload.term
  end
end
