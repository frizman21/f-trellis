require "test_helper"

class OrganizationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @report = SourceProcessingReport.create!(
      source: sources(:one),
      skill_revision: skill_revisions(:promoted_1),
      status: "complete"
    )

    @organization = Organization.create!
    @detail = OrganizationDetail.create!(
      organization: @organization,
      source_processing_report: @report,
      name: "National Aeronautics and Space Administration",
      acronym: "NASA",
      as_of: Time.zone.parse("1958-07-29"),
      confidence_tenths: 1000
    )
    @organization.update!(current_detail: @detail)
  end

  test "show displays the acronym" do
    get organization_path(@organization)

    assert_response :success
    assert_match "NASA", response.body
  end

  test "show renders for an organization with no current detail" do
    get organization_path(Organization.create!)

    assert_response :success
  end

  test "edit renders the acronym field" do
    get edit_organization_path(@organization)

    assert_response :success
    assert_match "organization[acronym]", response.body
    assert_match "NASA", response.body
  end

  test "update saves the acronym on the current detail" do
    patch organization_path(@organization), params: { organization: { acronym: "NASA HQ" } }

    assert_redirected_to organization_path(@organization)
    assert_equal "NASA HQ", @detail.reload.acronym
  end

  test "update trims whitespace and clears a blank acronym" do
    patch organization_path(@organization), params: { organization: { acronym: "  N A S A  " } }
    assert_equal "N A S A", @detail.reload.acronym

    patch organization_path(@organization), params: { organization: { acronym: "" } }
    assert_nil @detail.reload.acronym
  end

  test "update ignores attributes other than the acronym" do
    patch organization_path(@organization), params: {
      organization: { acronym: "NAS", name: "Renamed" }
    }

    assert_equal "NAS", @detail.reload.acronym
    assert_equal "National Aeronautics and Space Administration", @detail.name
  end

  test "edit on an organization with no current detail explains there is nothing to edit" do
    bare = Organization.create!

    get edit_organization_path(bare)

    assert_response :success
    assert_match "no current detail", response.body
  end

  test "update on an organization with no current detail redirects with an alert" do
    bare = Organization.create!

    patch organization_path(bare), params: { organization: { acronym: "XYZ" } }

    assert_redirected_to organization_path(bare)
    assert_equal "Organization has no current detail to edit.", flash[:alert]
  end

  test "index search matches on acronym" do
    get organizations_path, params: { q: "nasa" }

    assert_response :success
    assert_match "Acronym: NASA", response.body
    assert_match @detail.name, response.body
  end

  test "index search does not match an unrelated acronym" do
    get organizations_path, params: { q: "zzzznotanacronym" }

    assert_response :success
    assert_no_match @detail.name, response.body
  end

  test "show lists the people linked to the organization, with the type" do
    person = Person.create!
    person_detail = PersonDetail.create!(
      person: person,
      source_processing_report: @report,
      first_name: "Margaret",
      last_name: "Hamilton",
      as_of: Time.zone.parse("1969-07-20"),
      confidence_tenths: 1000
    )
    person.update!(current_detail: person_detail)

    relationship = PersonOrganization.create!(person: person, organization: @organization)
    relationship_detail = PersonOrganizationDetail.create!(
      person_organization: relationship,
      source_processing_report: @report,
      as_of: Time.zone.parse("1965-01-01"),
      confidence_tenths: 900
    )
    relationship_detail.person_organization_types = [ PersonOrganizationType.create!(name: "Employment") ]
    relationship.update!(current_detail: relationship_detail)

    get organization_path(@organization)

    assert_response :success
    assert_match "People", response.body
    assert_match "Margaret Hamilton", response.body
    assert_match "Employment", response.body
  end

  test "show lists relationships to other organizations, with the type" do
    other = Organization.create!
    other_detail = OrganizationDetail.create!(
      organization: other,
      source_processing_report: @report,
      name: "Jet Propulsion Laboratory",
      as_of: Time.zone.parse("1936-10-31"),
      confidence_tenths: 1000
    )
    other.update!(current_detail: other_detail)

    relationship = OrganizationOrganization.create!(
      organization_a: @organization,
      organization_b: other
    )
    relationship_detail = OrganizationOrganizationDetail.create!(
      organization_organization: relationship,
      source_processing_report: @report,
      as_of: Time.zone.parse("1958-12-03"),
      confidence_tenths: 950
    )
    relationship_detail.organization_organization_types = [
      OrganizationOrganizationType.create!(name: "Subsidiary")
    ]
    relationship.update!(current_detail: relationship_detail)

    get organization_path(@organization)

    assert_response :success
    assert_match "Related organizations", response.body
    assert_match "Jet Propulsion Laboratory", response.body
    assert_match "Subsidiary", response.body
  end

  test "show renders both relationship sections when the organization has none" do
    get organization_path(@organization)

    assert_response :success
    assert_match "People", response.body
    assert_match "No people recorded for this organization.", response.body
    assert_match "Related organizations", response.body
    assert_match "No relationships to other organizations recorded for this organization.", response.body
  end

  test "show renders the empty relationship sections for an organization with no current detail" do
    get organization_path(Organization.create!)

    assert_response :success
    assert_match "No people recorded for this organization.", response.body
    assert_match "No relationships to other organizations recorded for this organization.", response.body
  end
end
