require "test_helper"

class OrganizationDetailTest < ActiveSupport::TestCase
  def build_detail(attrs = {})
    report = SourceProcessingReport.create!(
      source: sources(:one),
      skill_revision: skill_revisions(:promoted_1),
      status: "complete"
    )

    OrganizationDetail.new({
      organization: Organization.create!,
      source_processing_report: report,
      name: "Example Organization",
      as_of: Time.current,
      confidence_tenths: 900
    }.merge(attrs))
  end

  test "acronym is optional" do
    detail = build_detail

    assert detail.valid?
    assert_nil detail.acronym
  end

  test "acronym is stripped" do
    detail = build_detail(acronym: "  NASA \n")
    detail.save!

    assert_equal "NASA", detail.reload.acronym
  end

  test "a blank acronym is stored as nil" do
    detail = build_detail(acronym: "   ")
    detail.save!

    assert_nil detail.reload.acronym
  end
end
