require "test_helper"

class PeopleControllerTest < ActionDispatch::IntegrationTest
  setup do
    @report = SourceProcessingReport.create!(
      source: sources(:one),
      skill_revision: skill_revisions(:promoted_1),
      status: "complete"
    )

    @person = Person.create!
    @detail = PersonDetail.create!(
      person: @person,
      source_processing_report: @report,
      first_name: "Margaret",
      last_name: "Hamilton",
      as_of: Time.zone.parse("1969-07-20"),
      confidence_tenths: 1000
    )
    @person.update!(current_detail: @detail)
  end

  test "show lists the organizations the person is linked to, with the type" do
    link_to_organization("National Aeronautics and Space Administration", "Employment")

    get person_path(@person)

    assert_response :success
    assert_match "Organizations", response.body
    assert_match "National Aeronautics and Space Administration", response.body
    assert_match "Employment", response.body
  end

  test "show lists relationships to other people, with the type" do
    link_to_person("Alan", "Turing", "Friendship")

    get person_path(@person)

    assert_response :success
    assert_match "Related people", response.body
    assert_match "Alan Turing", response.body
    assert_match "Friendship", response.body
  end

  test "show renders both relationship sections when the person has none" do
    get person_path(@person)

    assert_response :success
    assert_match "Organizations", response.body
    assert_match "No organizations recorded for this person.", response.body
    assert_match "Related people", response.body
    assert_match "No relationships to other people recorded for this person.", response.body
  end

  test "show renders for a person with no current detail" do
    get person_path(Person.create!)

    assert_response :success
    assert_match "No organizations recorded for this person.", response.body
    assert_match "No relationships to other people recorded for this person.", response.body
  end

  test "show names the other endpoint even when it has no current detail" do
    other = Person.create!
    relationship = PersonPerson.create!(person_a: @person, person_b: other)
    detail = PersonPersonDetail.create!(
      person_person: relationship,
      source_processing_report: @report,
      as_of: Time.zone.parse("1960-01-01"),
      confidence_tenths: 700
    )
    detail.person_person_types = [ PersonPersonType.create!(name: "Family") ]
    relationship.update!(current_detail: detail)

    get person_path(@person)

    assert_response :success
    assert_match "Person ##{other.id}", response.body
    assert_match "Family", response.body
  end

  private

  def link_to_organization(name, type_name)
    organization = Organization.create!
    organization_detail = OrganizationDetail.create!(
      organization: organization,
      source_processing_report: @report,
      name: name,
      as_of: Time.zone.parse("1958-07-29"),
      confidence_tenths: 1000
    )
    organization.update!(current_detail: organization_detail)

    relationship = PersonOrganization.create!(person: @person, organization: organization)
    detail = PersonOrganizationDetail.create!(
      person_organization: relationship,
      source_processing_report: @report,
      as_of: Time.zone.parse("1965-01-01"),
      confidence_tenths: 900
    )
    detail.person_organization_types = [ PersonOrganizationType.create!(name: type_name) ]
    relationship.update!(current_detail: detail)
    relationship
  end

  def link_to_person(first_name, last_name, type_name)
    other = Person.create!
    other_detail = PersonDetail.create!(
      person: other,
      source_processing_report: @report,
      first_name: first_name,
      last_name: last_name,
      as_of: Time.zone.parse("1936-01-01"),
      confidence_tenths: 1000
    )
    other.update!(current_detail: other_detail)

    relationship = PersonPerson.create!(person_a: @person, person_b: other)
    detail = PersonPersonDetail.create!(
      person_person: relationship,
      source_processing_report: @report,
      as_of: Time.zone.parse("1950-01-01"),
      confidence_tenths: 850
    )
    detail.person_person_types = [ PersonPersonType.create!(name: type_name) ]
    relationship.update!(current_detail: detail)
    relationship
  end
end
