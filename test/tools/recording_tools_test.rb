require "test_helper"

# The recording stand-ins an evaluation runs instead of the writing tools.
#
# Two things have to hold, and everything here is one of them: the model cannot
# tell the difference, and nothing reaches the knowledge graph.
class RecordingToolsTest < ActiveSupport::TestCase
  ENTITY_TABLES = [
    "Person.count", "Organization.count", "PersonDetail.count", "OrganizationDetail.count",
    "Part.count", "PartDetail.count", "PartDetailParameter.count",
    "PersonOrganization.count", "PersonOrganizationDetail.count",
    "PartOrganization.count", "PartOrganizationDetail.count",
    "PersonPerson.count", "PersonPersonDetail.count",
    "OrganizationOrganization.count", "OrganizationOrganizationDetail.count"
  ].freeze

  setup do
    @physical = PartType.find_or_create_by!(name: "Physical Part")
    @physical.part_type_parameters.find_or_create_by!(name: "weight") { |p| p.unit = "g" }

    @recorder = ProposalRecorder.new
    @people = RecordingUpsertPersonTool.new(@recorder)
    @orgs = RecordingUpsertOrganizationTool.new(@recorder)
    @person_org = RecordingLinkPersonOrganizationTool.new(@recorder)
    @org_org = RecordingLinkOrganizationOrganizationTool.new(@recorder)
    @parts = RecordingUpsertPartTool.new(@recorder)
    @part_org = RecordingLinkPartOrganizationTool.new(@recorder)
    @person_person = RecordingLinkPersonPersonTool.new(@recorder)
    @employment = PersonOrganizationType.find_or_create_by!(name: "Employment")
    @manufacturer = PartOrganizationType.find_or_create_by!(name: "Manufacturer")
    @partnership = OrganizationOrganizationType.find_or_create_by!(name: "Partnership")
    @founder = PersonPersonType.find_or_create_by!(name: "Co-Founder")
  end

  def two_people
    @people.execute(people: [ { first_name: "Ada", last_name: "Lovelace" },
                              { first_name: "Alan", last_name: "Turing" } ])[:results]
           .map { |r| r[:person_id] }
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

  # A person-to-person edge is keyed on the unordered pair too, so proposing
  # A–B and proposing B–A is the same contribution.
  test "a person link records the pair in a stable order and writes nothing" do
    ada, alan = two_people

    assert_no_difference ENTITY_TABLES do
      @person_person.execute(person_a_id: alan, person_b_id: ada, type: "Co-Founder")
    end

    link = @recorder.proposals.detect { |p| p["type"] == "person_person" }
    assert_equal [ "ada lovelace", "alan turing" ], link["people"]
    assert_equal "co-founder", link["relationship_type"]
  end

  test "a person cannot be linked to themselves, exactly as the writing tool refuses it" do
    ada, = two_people

    result = @person_person.execute(person_a_id: ada, person_b_id: ada, type: "Co-Founder")

    assert_match(/must be different/, result[:error])
  end

  test "a person link to an id this run never issued is refused" do
    ada, = two_people

    result = @person_person.execute(person_a_id: ada, person_b_id: 99, type: "Co-Founder")

    assert_equal "no person #99", result[:error]
  end

  test "a person link can use a type minted earlier in the same run" do
    RecordingCreatePersonPersonTypeTool.new(@recorder)
      .execute(name: "Mentorship", description: "One person mentors another.")
    ada, alan = two_people

    assert_no_difference ENTITY_TABLES do
      result = @person_person.execute(person_a_id: ada, person_b_id: alan, type: "Mentorship")

      assert_nil result[:error]
    end

    link = @recorder.proposals.detect { |p| p["type"] == "person_person" }
    assert_equal "mentorship", link["relationship_type"]
  end

  test "a person link to a type no one minted or configured is refused" do
    ada, alan = two_people

    result = @person_person.execute(person_a_id: ada, person_b_id: alan, type: "Nonsense")

    assert_match(/PersonPersonType 'Nonsense' is not configured/, result[:error])
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

  # --- Parts ----------------------------------------------------------------

  test "a part is captured with its types and specifications, and nothing is written" do
    assert_no_difference ENTITY_TABLES do
      @parts.execute(parts: [ { name: "Drone One", part_types: [ "Physical Part" ],
                                specifications: [ { parameter: "weight", value: "624",
                                                    as_stated: "1.375 lb" } ] } ])
    end

    part = @recorder.proposals.detect { |p| p["type"] == "part" }
    assert_equal "drone one", part["name"]
    assert_equal [ "physical part" ], part["part_types"]
    assert_equal [ { "parameter" => "weight", "value" => "624", "unit" => "g" } ], part["specifications"]
  end

  # A specification is not a contribution of its own — otherwise a model could
  # out-rank another by listing more numbers about the same part.
  test "specifications ride inside the part rather than counting separately" do
    @parts.execute(parts: [ { name: "Drone One", part_types: [ "Physical Part" ],
                              specifications: [ { parameter: "weight", value: "624" } ] } ])

    assert_equal 1, @recorder.proposals.size
  end

  # `as_stated` is what the page said, not what was recorded. Two runs that both
  # put the weight at 624 g agree, whether one read "1.375 lb" and the other "624 g".
  test "how the page worded a value does not change the proposal" do
    other = ProposalRecorder.new
    RecordingUpsertPartTool.new(other).execute(
      parts: [ { name: "Drone One", part_types: [ "Physical Part" ],
                 specifications: [ { parameter: "weight", value: "624", as_stated: "624 g" } ] } ]
    )
    @parts.execute(parts: [ { name: "Drone One", part_types: [ "Physical Part" ],
                              specifications: [ { parameter: "weight", value: "624",
                                                  as_stated: "1.375 lb" } ] } ])

    assert_equal ProposalSet.new(other.proposals).digest, ProposalSet.new(@recorder.proposals).digest
  end

  # The taxonomy is most of what upsert_part enforces. A stand-in that accepted
  # anything would score a model for specifications the real run threw away.
  test "the stand-in refuses the specifications the writing tool refuses" do
    result = @parts.execute(parts: [
      { name: "Drone One", part_types: [ "Physical Part" ],
        specifications: [ { parameter: "weight", value: "1.375", unit: "lb" },
                          { parameter: "capacity", value: "5000" } ] }
    ])[:results].first

    assert_equal 0, result[:specifications_recorded]
    assert_equal 2, result[:specification_errors].size
    assert_empty @recorder.proposals.detect { |p| p["type"] == "part" }["specifications"]
  end

  test "a part naming no configured type is refused, exactly as the writing tool refuses it" do
    result = @parts.execute(parts: [ { name: "Drone One", part_types: [ "Spaceship" ] } ])[:results].first

    assert_match(/no part type matched Spaceship/, result[:error])
    assert_empty @recorder.proposals
  end

  def one_part
    @parts.execute(parts: [ { name: "Drone One", part_types: [ "Physical Part" ] } ])[:results]
          .first[:part_id]
  end

  test "a part-to-organization link is captured against the names and writes nothing" do
    part_id = one_part
    org_id = @orgs.execute(organizations: [ { name: "Acme Corp" } ])[:results].first[:organization_id]

    assert_no_difference ENTITY_TABLES do
      @part_org.execute(part_id: part_id, organization_id: org_id, type: "Manufacturer",
                        additional_attributes: { "program" => "X-3" })
    end

    link = @recorder.proposals.detect { |p| p["type"] == "part_organization" }
    assert_equal "drone one", link["part"]
    assert_equal "acme corp", link["organization"]
    assert_equal "manufacturer", link["relationship_type"]
    assert_equal({ "program" => "x-3" }, link["attributes"])
  end

  test "a part link to an id this run never issued is refused" do
    org_id = @orgs.execute(organizations: [ { name: "Acme Corp" } ])[:results].first[:organization_id]

    assert_equal "no part #99", @part_org.execute(part_id: 99, organization_id: org_id,
                                                  type: "Manufacturer")[:error]
    assert_equal "no organization #99", @part_org.execute(part_id: one_part, organization_id: 99,
                                                          type: "Manufacturer")[:error]
    assert_nil @recorder.proposals.detect { |p| p["type"] == "part_organization" }
  end

  # No tool mints part-organization types, so an unconfigured name is a mistake
  # the writing run would refuse — there is no minted case to allow here.
  test "a part link to a type no one configured is refused" do
    part_id = one_part
    org_id = @orgs.execute(organizations: [ { name: "Acme Corp" } ])[:results].first[:organization_id]

    result = @part_org.execute(part_id: part_id, organization_id: org_id, type: "Nonsense")

    assert_match(/PartOrganizationType 'Nonsense' is not configured/, result[:error])
    assert_nil @recorder.proposals.detect { |p| p["type"] == "part_organization" }
  end
end
