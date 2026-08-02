require "test_helper"

# The recording stand-ins an evaluation runs instead of the writing tools.
#
# Two things have to hold, and everything here is one of them: the model cannot
# tell the difference, and nothing reaches the knowledge graph.
class RecordingToolsTest < ActiveSupport::TestCase
  ENTITY_TABLES = [
    "Person.count", "Organization.count", "PersonDetail.count", "OrganizationDetail.count",
    "PersonOrganization.count", "PersonOrganizationDetail.count",
    "OrganizationOrganization.count", "OrganizationOrganizationDetail.count"
  ].freeze

  setup do
    @recorder = ProposalRecorder.new
    @people = RecordingUpsertPersonTool.new(@recorder)
    @orgs = RecordingUpsertOrganizationTool.new(@recorder)
    @person_org = RecordingLinkPersonOrganizationTool.new(@recorder)
    @org_org = RecordingLinkOrganizationOrganizationTool.new(@recorder)
    @employment = PersonOrganizationType.find_or_create_by!(name: "Employment")
    @partnership = OrganizationOrganizationType.find_or_create_by!(name: "Partnership")
  end

  test "a whole batch is captured and nothing is written" do
    assert_no_difference ENTITY_TABLES do
      @orgs.execute(organizations: [ { name: "Acme Corp", acronym: "ACME" }, { name: "Beta Inc" } ])
      @people.execute(people: [ { first_name: "Jane", last_name: "Doe" } ])
    end

    assert_equal 3, @recorder.proposals.size
    assert_includes @recorder.proposals,
                    { "type" => "organization", "name" => "acme corp", "acronym" => "acme",
                      "attributes" => {} }
  end

  test "a link is captured against the names, not the synthetic ids" do
    person_id = @people.execute(people: [ { first_name: "Jane", last_name: "Doe" } ])[:results].first[:person_id]
    org_id = @orgs.execute(organizations: [ { name: "Acme Corp" } ])[:results].first[:organization_id]

    assert_no_difference ENTITY_TABLES do
      @person_org.execute(person_id: person_id, organization_id: org_id, type: "Employment")
    end

    link = @recorder.proposals.detect { |p| p["type"] == "person_organization" }
    assert_equal "jane doe", link["person"]
    assert_equal "acme corp", link["organization"]
    assert_equal "employment", link["relationship_type"]
  end

  # An organization-to-organization edge is keyed on the unordered pair, so
  # proposing A–B and proposing B–A is the same contribution.
  test "an organization link records the pair in a stable order" do
    ids = @orgs.execute(organizations: [ { name: "Zeta" }, { name: "Alpha" } ])[:results].map { |r| r[:organization_id] }

    @org_org.execute(organization_a_id: ids.first, organization_b_id: ids.last, type: "Partnership")

    link = @recorder.proposals.detect { |p| p["type"] == "organization_organization" }
    assert_equal [ "alpha", "zeta" ], link["organizations"]
  end

  # A model reading the response decides what to do next from it, so an error
  # where the writing tool would have succeeded would change its behaviour and
  # corrupt the comparison.
  test "a recording tool returns the same result shape as its writing counterpart" do
    report = SourceProcessingReport.create!(source: sources(:one),
                                            skill_revision: skill_revisions(:promoted_1),
                                            status: "processing")

    recorded = @orgs.execute(organizations: [ { name: "Acme Corp" } ])[:results].first
    written = UpsertOrganizationTool.new(report).execute(organizations: [ { name: "Acme Corp" } ])[:results].first

    assert_equal written.keys.sort, recorded.keys.sort
    assert_equal written.transform_values(&:class), recorded.transform_values(&:class)
  end

  test "the same name twice in one run reports created false the second time" do
    results = @orgs.execute(organizations: [ { name: "Acme Corp" }, { name: "ACME CORP" } ])[:results]

    assert results[0][:created]
    assert_not results[1][:created]
    assert_equal results[0][:organization_id], results[1][:organization_id]
  end

  test "an empty batch is refused, exactly as the writing tool refuses it" do
    assert_equal({ error: "organizations must be a non-empty array" }, @orgs.execute(organizations: []))
    assert_equal({ error: "people must be a non-empty array" }, @people.execute(people: []))
  end

  # The writing tool refuses these too. Waving them through would credit a model
  # for a link the real run could never have made.
  test "a link to an id this run never issued is refused" do
    result = @person_org.execute(person_id: 99, organization_id: 99, type: "Employment")

    assert_equal "no person #99", result[:error]
    assert_empty @recorder.proposals
  end

  test "a relationship type that is not configured is refused" do
    person_id = @people.execute(people: [ { first_name: "Jane", last_name: "Doe" } ])[:results].first[:person_id]
    org_id = @orgs.execute(organizations: [ { name: "Acme" } ])[:results].first[:organization_id]

    result = @person_org.execute(person_id: person_id, organization_id: org_id, type: "Nonsense")

    assert_match(/is not configured/, result[:error])
  end

  test "an organization cannot be linked to itself" do
    id = @orgs.execute(organizations: [ { name: "Acme" } ])[:results].first[:organization_id]

    result = @org_org.execute(organization_a_id: id, organization_b_id: id, type: "Partnership")

    assert_match(/must be different/, result[:error])
  end

  # The upsert schemas declare attributes as [{key:, value:}] — a strict JSON
  # schema cannot express a free-form object — while the link tools take a flat
  # hash. Both have to land in the same normalised place.
  test "extra attributes are captured in both shapes the schemas allow" do
    org_id = @orgs.execute(organizations: [
      { name: "Acme", additional_attributes: [ { key: "sector", value: "Defense" } ] }
    ])[:results].first[:organization_id]
    person_id = @people.execute(people: [ { first_name: "Jane", last_name: "Doe" } ])[:results].first[:person_id]

    @person_org.execute(person_id: person_id, organization_id: org_id, type: "Employment",
                        additional_attributes: { "role" => "CEO" })

    org = @recorder.proposals.detect { |p| p["type"] == "organization" }
    link = @recorder.proposals.detect { |p| p["type"] == "person_organization" }
    assert_equal({ "sector" => "defense" }, org["attributes"])
    assert_equal({ "role" => "ceo" }, link["attributes"])
  end
end
