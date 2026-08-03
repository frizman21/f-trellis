require "test_helper"

# The tools that let a model extend the relationship-type vocabulary, and the
# stand-ins an evaluation runs instead.
#
# The thing worth guarding is not that a type gets created — it is that a second
# spelling of an existing type does not, because vocabulary is the one table
# where a near-duplicate is worse than a missing row.
class CreateRelationshipTypeToolsTest < ActiveSupport::TestCase
  setup do
    @report = SourceProcessingReport.create!(
      source: sources(:one),
      skill_revision: skill_revisions(:promoted_1),
      status: "processing"
    )
    @person_org = CreatePersonOrganizationTypeTool.new(@report)
    @person_person = CreatePersonPersonTypeTool.new(@report)
    @recorder = ProposalRecorder.new
  end

  # --- Writing tools --------------------------------------------------------

  test "creates a person-organization type with its description and attribute keys" do
    assert_difference "PersonOrganizationType.count", 1 do
      result = @person_org.execute(name: "Board Membership",
                                   description: "Holds a seat on the organization's board.",
                                   additional_attribute_keys: [ "seat", "since" ])

      assert result[:created]
      assert_equal "Board Membership", result[:name]
      assert_equal %w[seat since], result[:additional_attribute_keys]

      type = PersonOrganizationType.find(result[:person_organization_type_id])
      assert_equal "Holds a seat on the organization's board.", type.description
    end
  end

  test "creates a person-person type" do
    assert_difference "PersonPersonType.count", 1 do
      result = @person_person.execute(name: "Co-Founder",
                                      description: "Founded an organization together.")

      assert result[:created]
      assert_equal "Co-Founder", PersonPersonType.find(result[:person_person_type_id]).name
      assert_empty result[:additional_attribute_keys]
    end
  end

  # The unique index on name is case-sensitive, so nothing but this stops
  # "Employment" and "employment" from becoming two ideas.
  test "a name that differs only in case returns the existing type instead of a second one" do
    first = @person_org.execute(name: "Employment", description: "Works for the organization.")

    assert_no_difference "PersonOrganizationType.count" do
      second = @person_org.execute(name: "eMPLOYMENT", description: "Something else entirely.")

      assert_not second[:created]
      assert_equal first[:person_organization_type_id], second[:person_organization_type_id]
      assert_equal "Employment", second[:name], "the configured spelling wins"
    end
  end

  test "an existing type keeps the description it already had" do
    @person_person.execute(name: "Mentorship", description: "One person mentors another.")
    @person_person.execute(name: "Mentorship", description: "Rewritten by a later page.")

    assert_equal "One person mentors another.", PersonPersonType.find_by(name: "Mentorship").description
  end

  # A type nobody can tell apart from its neighbours is not usable vocabulary.
  test "a type with no name or no description is refused" do
    assert_no_difference [ "PersonOrganizationType.count", "PersonPersonType.count" ] do
      assert_equal({ error: "name is required" },
                   @person_org.execute(name: "  ", description: "Anything."))
      assert_equal({ error: "description is required" },
                   @person_person.execute(name: "Mentorship", description: ""))
    end
  end

  test "blank and duplicate attribute keys are dropped" do
    result = @person_org.execute(name: "Advisory", description: "Advises the organization.",
                                 additional_attribute_keys: [ "focus", " ", "focus", " tenure " ])

    assert_equal %w[focus tenure], result[:additional_attribute_keys]
  end

  # --- The vocabulary the model is shown ------------------------------------

  test "the description lists the types that already exist" do
    @person_org.execute(name: "Employment", description: "Works for the organization.",
                        additional_attribute_keys: [ "title" ])

    description = CreatePersonOrganizationTypeTool.new(@report).description

    assert_match(/Employment: Works for the organization\./, description)
    assert_match(/attributes: title/, description)
  end

  test "the description says so when nothing is configured yet" do
    PersonPersonType.delete_all

    assert_match(/none configured yet/, CreatePersonPersonTypeTool.new(@report).description)
  end

  # --- Recording stand-ins --------------------------------------------------

  test "the stand-ins present the writing tools' names, descriptions and schemas" do
    [ [ RecordingCreatePersonOrganizationTypeTool, CreatePersonOrganizationTypeTool ],
      [ RecordingCreatePersonPersonTypeTool, CreatePersonPersonTypeTool ] ].each do |recording, writing|
      stand_in = recording.new(@recorder)
      real = writing.new(nil)

      assert_equal real.name, stand_in.name
      assert_equal real.description, stand_in.description
      assert_equal real.params_schema, stand_in.params_schema
    end
  end

  # An evaluation that left its invented types behind would rewrite the tool
  # description every later run reads, and the runs would stop being comparable.
  test "a stand-in writes no vocabulary and returns the writing tool's result shape" do
    stand_in = RecordingCreatePersonOrganizationTypeTool.new(@recorder)

    recorded = nil
    assert_no_difference [ "PersonOrganizationType.count", "PersonPersonType.count" ] do
      recorded = stand_in.execute(name: "Board Membership", description: "Holds a seat.")
      RecordingCreatePersonPersonTypeTool.new(@recorder)
        .execute(name: "Mentorship", description: "One person mentors another.")
    end

    written = @person_org.execute(name: "Board Membership", description: "Holds a seat.")

    assert_equal written.keys.sort, recorded.keys.sort
    assert_equal written.transform_values(&:class), recorded.transform_values(&:class)
    assert recorded[:created]
  end

  test "a stand-in reports created false for a type that is already configured" do
    @person_org.execute(name: "Employment", description: "Works for the organization.")
    result = RecordingCreatePersonOrganizationTypeTool.new(@recorder)
               .execute(name: "employment", description: "Works for the organization.")

    assert_not result[:created]
    assert_equal "Employment", result[:name]
  end

  test "the same new type twice in one run reports created false the second time" do
    stand_in = RecordingCreatePersonPersonTypeTool.new(@recorder)
    first = stand_in.execute(name: "Mentorship", description: "One person mentors another.")
    second = stand_in.execute(name: "MENTORSHIP", description: "One person mentors another.")

    assert first[:created]
    assert_not second[:created]
    assert_equal first[:person_person_type_id], second[:person_person_type_id]
  end

  # Minting vocabulary is not a contribution to the knowledge base. Counting it
  # as one would let a model out-rank another by inventing names.
  test "a minted type is not itself a proposal" do
    RecordingCreatePersonOrganizationTypeTool.new(@recorder)
      .execute(name: "Board Membership", description: "Holds a seat.")

    assert_empty @recorder.proposals
  end

  # The sequence a real run allows: mint the type, then link with it.
  test "a link can use a type minted earlier in the same evaluation" do
    RecordingCreatePersonOrganizationTypeTool.new(@recorder)
      .execute(name: "Board Membership", description: "Holds a seat.")

    people = RecordingUpsertPersonTool.new(@recorder)
    orgs = RecordingUpsertOrganizationTool.new(@recorder)
    person_id = people.execute(people: [ { first_name: "Jane", last_name: "Doe" } ])[:results].first[:person_id]
    org_id = orgs.execute(organizations: [ { name: "Acme Corp" } ])[:results].first[:organization_id]

    result = RecordingLinkPersonOrganizationTool.new(@recorder)
               .execute(person_id: person_id, organization_id: org_id, type: "Board Membership")

    assert_nil result[:error]
    link = @recorder.proposals.detect { |p| p["type"] == "person_organization" }
    assert_equal "board membership", link["relationship_type"]
  end

  test "a link to a type no one minted or configured is still refused" do
    people = RecordingUpsertPersonTool.new(@recorder)
    orgs = RecordingUpsertOrganizationTool.new(@recorder)
    person_id = people.execute(people: [ { first_name: "Jane", last_name: "Doe" } ])[:results].first[:person_id]
    org_id = orgs.execute(organizations: [ { name: "Acme Corp" } ])[:results].first[:organization_id]

    result = RecordingLinkPersonOrganizationTool.new(@recorder)
               .execute(person_id: person_id, organization_id: org_id, type: "Nonsense")

    assert_match(/is not configured/, result[:error])
  end
end
