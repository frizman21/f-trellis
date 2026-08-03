require "test_helper"

class LinkPersonPersonToolTest < ActiveSupport::TestCase
  setup do
    @report = SourceProcessingReport.create!(
      source: sources(:one),
      skill_revision: skill_revisions(:promoted_1),
      status: "processing"
    )
    @tool = LinkPersonPersonTool.new(@report)
    @founder = PersonPersonType.find_or_create_by!(name: "Co-Founder")
    @ada = Person.create!
    @alan = Person.create!
  end

  test "creates the edge, the detail and the type attachment" do
    assert_difference [ "PersonPerson.count", "PersonPersonDetail.count" ], 1 do
      result = @tool.execute(person_a_id: @ada.id, person_b_id: @alan.id, type: "Co-Founder")

      edge = PersonPerson.find(result[:person_person_id])
      assert_equal result[:detail_id], edge.current_detail_id
      assert_equal [ @founder ], edge.current_detail.person_person_types
      assert_equal @report, edge.current_detail.source_processing_report
      assert_equal "Co-Founder", result[:type]
    end
  end

  # The edge is keyed on the unordered pair, so a page naming the two in one
  # order and a page naming them in the other must not make two edges.
  test "the same pair in either order reuses one edge" do
    first = @tool.execute(person_a_id: @ada.id, person_b_id: @alan.id, type: "Co-Founder")

    assert_difference "PersonPersonDetail.count", 1 do
      assert_no_difference "PersonPerson.count" do
        second = @tool.execute(person_a_id: @alan.id, person_b_id: @ada.id, type: "Co-Founder")

        assert_equal first[:person_person_id], second[:person_person_id]
      end
    end
  end

  test "each call inserts a new detail and moves the current pointer" do
    @tool.execute(person_a_id: @ada.id, person_b_id: @alan.id, type: "Co-Founder")
    second = @tool.execute(person_a_id: @ada.id, person_b_id: @alan.id, type: "Co-Founder",
                           confidence_tenths: 950)

    edge = PersonPerson.find(second[:person_person_id])
    assert_equal second[:detail_id], edge.current_detail_id
    assert_equal 950, edge.current_detail.confidence_tenths
    assert_equal 2, edge.person_person_details.count
  end

  test "confidence is clamped and defaults to 800" do
    default = @tool.execute(person_a_id: @ada.id, person_b_id: @alan.id, type: "Co-Founder")
    over = @tool.execute(person_a_id: @ada.id, person_b_id: @alan.id, type: "Co-Founder",
                         confidence_tenths: 5000)

    assert_equal 800, PersonPersonDetail.find(default[:detail_id]).confidence_tenths
    assert_equal 1000, PersonPersonDetail.find(over[:detail_id]).confidence_tenths
  end

  # Direction on an asymmetric type is carried in the attributes, because the
  # edge itself is unordered.
  test "direction-coding attributes are kept and non-scalars dropped" do
    result = @tool.execute(person_a_id: @ada.id, person_b_id: @alan.id, type: "Co-Founder",
                           additional_attributes: { "mentor_person_id" => @ada.id,
                                                    "note" => [ "nested" ] })

    assert_equal({ "mentor_person_id" => @ada.id },
                 PersonPersonDetail.find(result[:detail_id]).additional_attributes)
  end

  test "a person cannot be linked to themselves" do
    assert_no_difference "PersonPerson.count" do
      result = @tool.execute(person_a_id: @ada.id, person_b_id: @ada.id, type: "Co-Founder")

      assert_equal "person_a_id and person_b_id must be different", result[:error]
    end
  end

  test "an unknown person or an unconfigured type is refused" do
    assert_no_difference [ "PersonPerson.count", "PersonPersonDetail.count" ] do
      assert_equal "no person #999999",
                   @tool.execute(person_a_id: 999_999, person_b_id: @alan.id, type: "Co-Founder")[:error]
      assert_match(/PersonPersonType 'Nonsense' is not configured/,
                   @tool.execute(person_a_id: @ada.id, person_b_id: @alan.id, type: "Nonsense")[:error])
      assert_equal "type is required",
                   @tool.execute(person_a_id: @ada.id, person_b_id: @alan.id, type: "  ")[:error]
    end
  end

  # The pair minting a type then using it is the whole reason
  # create_person_person_type exists.
  test "a type minted by create_person_person_type can be linked with immediately" do
    minted = CreatePersonPersonTypeTool.new(@report)
               .execute(name: "Mentorship", description: "One person mentors another.")

    result = @tool.execute(person_a_id: @ada.id, person_b_id: @alan.id, type: minted[:name])

    assert_nil result[:error]
    assert_equal "Mentorship", result[:type]
  end
end
