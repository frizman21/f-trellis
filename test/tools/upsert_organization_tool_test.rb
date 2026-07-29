require "test_helper"

class UpsertOrganizationToolTest < ActiveSupport::TestCase
  setup do
    @report = SourceProcessingReport.create!(
      source: sources(:one),
      skill_revision: skill_revisions(:promoted_1),
      status: "processing"
    )
    @tool = UpsertOrganizationTool.new(@report)
  end

  test "stores the acronym on the new detail" do
    result = @tool.execute(
      name: "National Aeronautics and Space Administration",
      acronym: "NASA"
    )

    assert result[:created]
    assert_equal "NASA", OrganizationDetail.find(result[:detail_id]).acronym
  end

  test "acronym is optional" do
    result = @tool.execute(name: "Acme Corp")

    assert_nil OrganizationDetail.find(result[:detail_id]).acronym
  end

  test "a blank acronym is stored as nil" do
    result = @tool.execute(name: "Acme Corp", acronym: "   ")

    assert_nil OrganizationDetail.find(result[:detail_id]).acronym
  end

  test "an updated acronym lands on the organization's new current detail" do
    first  = @tool.execute(name: "Acme Corp")
    second = @tool.execute(name: "Acme Corp", acronym: "AC")

    assert_equal first[:organization_id], second[:organization_id]
    refute second[:created]

    organization = Organization.find(second[:organization_id])
    assert_equal "AC", organization.current_detail.acronym
  end
end
