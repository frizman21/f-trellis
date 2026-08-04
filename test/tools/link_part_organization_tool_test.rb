require "test_helper"

class LinkPartOrganizationToolTest < ActiveSupport::TestCase
  setup do
    @report = SourceProcessingReport.create!(
      source: sources(:one),
      skill_revision: skill_revisions(:promoted_1),
      status: "processing"
    )
    @tool = LinkPartOrganizationTool.new(@report)
    @manufacturer = PartOrganizationType.find_or_create_by!(name: "Manufacturer")
    @part = Part.create!
    @organization = Organization.create!
  end

  test "creates the edge, the detail and the type attachment" do
    assert_difference [ "PartOrganization.count", "PartOrganizationDetail.count" ], 1 do
      result = @tool.execute(part_id: @part.id, organization_id: @organization.id, type: "Manufacturer")

      edge = PartOrganization.find(result[:part_organization_id])
      assert_equal result[:detail_id], edge.current_detail_id
      assert_equal [ @manufacturer ], edge.current_detail.part_organization_types
      assert_equal @report, edge.current_detail.source_processing_report
      assert_equal @part, edge.part
      assert_equal @organization, edge.organization
      assert_equal "Manufacturer", result[:type]
    end
  end

  test "a second call for the same pair reuses the edge and moves the current pointer" do
    first = @tool.execute(part_id: @part.id, organization_id: @organization.id, type: "Manufacturer")

    assert_difference "PartOrganizationDetail.count", 1 do
      assert_no_difference "PartOrganization.count" do
        second = @tool.execute(part_id: @part.id, organization_id: @organization.id,
                               type: "Manufacturer", confidence_tenths: 950)

        assert_equal first[:part_organization_id], second[:part_organization_id]

        edge = PartOrganization.find(second[:part_organization_id])
        assert_equal second[:detail_id], edge.current_detail_id
        assert_equal 950, edge.current_detail.confidence_tenths
        assert_equal 2, edge.part_organization_details.count
      end
    end
  end

  test "an unknown part or organization is refused and writes nothing" do
    assert_no_difference [ "PartOrganization.count", "PartOrganizationDetail.count" ] do
      assert_equal "no part #999999",
                   @tool.execute(part_id: 999_999, organization_id: @organization.id,
                                 type: "Manufacturer")[:error]
      assert_equal "no organization #999999",
                   @tool.execute(part_id: @part.id, organization_id: 999_999,
                                 type: "Manufacturer")[:error]
    end
  end

  # Manufacturer / Consumer / Demand are a closed set — no tool mints new ones,
  # so a name outside it is a mistake, not a new category.
  test "an unconfigured type is refused by name and writes nothing" do
    assert_no_difference [ "PartOrganization.count", "PartOrganizationDetail.count" ] do
      assert_match(/PartOrganizationType 'Nonsense' is not configured/,
                   @tool.execute(part_id: @part.id, organization_id: @organization.id,
                                 type: "Nonsense")[:error])
      assert_equal "type is required",
                   @tool.execute(part_id: @part.id, organization_id: @organization.id, type: "  ")[:error]
    end
  end

  test "confidence is clamped and defaults to 800" do
    default = @tool.execute(part_id: @part.id, organization_id: @organization.id, type: "Manufacturer")
    over = @tool.execute(part_id: @part.id, organization_id: @organization.id,
                         type: "Manufacturer", confidence_tenths: 5000)
    under = @tool.execute(part_id: @part.id, organization_id: @organization.id,
                          type: "Manufacturer", confidence_tenths: -20)

    assert_equal 800, PartOrganizationDetail.find(default[:detail_id]).confidence_tenths
    assert_equal 1000, PartOrganizationDetail.find(over[:detail_id]).confidence_tenths
    assert_equal 0, PartOrganizationDetail.find(under[:detail_id]).confidence_tenths
  end

  test "as_of is parsed when given and defaults to now when blank" do
    stated = @tool.execute(part_id: @part.id, organization_id: @organization.id,
                           type: "Manufacturer", as_of: "2020-03-04T05:06:07Z")
    blank = @tool.execute(part_id: @part.id, organization_id: @organization.id,
                          type: "Manufacturer", as_of: "")

    assert_equal Time.utc(2020, 3, 4, 5, 6, 7), PartOrganizationDetail.find(stated[:detail_id]).as_of
    assert_in_delta Time.current, PartOrganizationDetail.find(blank[:detail_id]).as_of, 5
  end

  test "additional attributes keep scalars and drop everything else" do
    result = @tool.execute(part_id: @part.id, organization_id: @organization.id, type: "Manufacturer",
                           additional_attributes: { "program" => "X-3", "quantity" => 12,
                                                    "sole_source" => true, "note" => [ "nested" ] })

    assert_equal({ "program" => "X-3", "quantity" => 12, "sole_source" => true },
                 PartOrganizationDetail.find(result[:detail_id]).additional_attributes)
  end
end
