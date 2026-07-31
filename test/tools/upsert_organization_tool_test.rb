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

  def results_for(*entries)
    @tool.execute(organizations: entries)[:results]
  end

  test "records a whole batch in one call" do
    assert_difference [ "Organization.count", "OrganizationDetail.count" ], 3 do
      results = results_for({ name: "Acme Corp" }, { name: "Beta Inc" }, { name: "Gamma LLC" })

      assert_equal 3, results.size
      assert results.all? { |r| r[:created] }
    end
  end

  test "returns results in input order" do
    results = results_for({ name: "First" }, { name: "Second" }, { name: "Third" })

    names = results.map { |r| OrganizationDetail.find(r[:detail_id]).name }
    assert_equal %w[First Second Third], names
  end

  test "one bad entry does not stop the rest of the batch" do
    results = results_for({ name: "Good One" }, { name: "   " }, { name: "Good Two" })

    assert_equal "name is required", results[1][:error]
    assert results[0][:organization_id].present?
    assert results[2][:organization_id].present?
    assert_equal 2, OrganizationDetail.where(source_processing_report: @report).count
  end

  test "accepts string keys as they arrive from JSON" do
    results = results_for({ "name" => "String Keyed", "acronym" => "SK" })

    detail = OrganizationDetail.find(results[0][:detail_id])
    assert_equal "String Keyed", detail.name
    assert_equal "SK", detail.acronym
  end

  test "an empty array is rejected without touching the database" do
    assert_no_difference "Organization.count" do
      assert_equal "organizations must be a non-empty array", @tool.execute(organizations: [])[:error]
    end
  end

  test "stores the acronym on the new detail" do
    results = results_for(
      { name: "National Aeronautics and Space Administration", acronym: "NASA" }
    )

    assert results[0][:created]
    assert_equal "NASA", OrganizationDetail.find(results[0][:detail_id]).acronym
  end

  test "acronym is optional" do
    results = results_for({ name: "Acme Corp" })

    assert_nil OrganizationDetail.find(results[0][:detail_id]).acronym
  end

  test "a blank acronym is stored as nil" do
    results = results_for({ name: "Acme Corp", acronym: "   " })

    assert_nil OrganizationDetail.find(results[0][:detail_id]).acronym
  end

  test "an existing organization is reused rather than duplicated" do
    first = results_for({ name: "Acme Corp" })[0]

    assert_no_difference "Organization.count" do
      second = results_for({ name: "acme corp", acronym: "AC" })[0]

      assert_equal first[:organization_id], second[:organization_id]
      assert_not second[:created]
    end
  end

  test "a name repeated within one batch reuses the organization" do
    assert_difference "Organization.count", 1 do
      results = results_for({ name: "Acme Corp" }, { name: "ACME CORP", acronym: "AC" })

      assert_equal results[0][:organization_id], results[1][:organization_id]
      assert results[0][:created]
      assert_not results[1][:created]
    end
  end

  test "current_detail points at the last detail written for that organization" do
    results = results_for({ name: "Acme Corp" }, { name: "Acme Corp", acronym: "AC" })

    organization = Organization.find(results[1][:organization_id])
    assert_equal results[1][:detail_id], organization.current_detail_id
    assert_equal "AC", organization.current_detail.acronym
  end

  test "confidence clamps per entry and defaults when omitted" do
    results = results_for(
      { name: "Too High", confidence_tenths: 5000 },
      { name: "Too Low", confidence_tenths: -20 },
      { name: "Omitted" }
    )

    assert_equal 1000, OrganizationDetail.find(results[0][:detail_id]).confidence_tenths
    assert_equal 0, OrganizationDetail.find(results[1][:detail_id]).confidence_tenths
    assert_equal 800, OrganizationDetail.find(results[2][:detail_id]).confidence_tenths
  end

  test "additional_attributes drops non-scalar values per entry" do
    results = results_for(
      { name: "Acme Corp",
        additional_attributes: { "sector" => "defense", "nested" => { "a" => 1 }, "count" => 3 } }
    )

    attrs = OrganizationDetail.find(results[0][:detail_id]).additional_attributes
    assert_equal({ "sector" => "defense", "count" => 3 }, attrs)
  end

  test "additional_attributes accepts the key/value pair shape the schema declares" do
    results = results_for(
      { name: "Acme Corp",
        additional_attributes: [
          { "key" => "sector", "value" => "defense" },
          { "key" => "hq", "value" => "Denver" }
        ] }
    )

    attrs = OrganizationDetail.find(results[0][:detail_id]).additional_attributes
    assert_equal({ "sector" => "defense", "hq" => "Denver" }, attrs)
  end

  test "additional_attributes ignores pairs with a blank key or a non-scalar value" do
    results = results_for(
      { name: "Acme Corp",
        additional_attributes: [
          { "key" => "", "value" => "dropped" },
          { "key" => "nested", "value" => { "a" => 1 } },
          { "key" => "kept", "value" => "yes" }
        ] }
    )

    attrs = OrganizationDetail.find(results[0][:detail_id]).additional_attributes
    assert_equal({ "kept" => "yes" }, attrs)
  end

  test "every detail is attached to the active report" do
    results = results_for({ name: "One" }, { name: "Two" })

    results.each do |r|
      assert_equal @report.id, OrganizationDetail.find(r[:detail_id]).source_processing_report_id
    end
  end
end
