require "test_helper"

class UpsertPersonToolTest < ActiveSupport::TestCase
  setup do
    @report = SourceProcessingReport.create!(
      source: sources(:one),
      skill_revision: skill_revisions(:promoted_1),
      status: "processing"
    )
    @tool = UpsertPersonTool.new(@report)
  end

  def results_for(*entries)
    @tool.execute(people: entries)[:results]
  end

  test "records a whole batch in one call" do
    assert_difference [ "Person.count", "PersonDetail.count" ], 3 do
      results = results_for(
        { first_name: "Ada", last_name: "Lovelace" },
        { first_name: "Alan", last_name: "Turing" },
        { first_name: "Grace", last_name: "Hopper" }
      )

      assert_equal 3, results.size
      assert results.all? { |r| r[:created] }
    end
  end

  test "returns results in input order" do
    results = results_for(
      { first_name: "First", last_name: "One" },
      { first_name: "Second", last_name: "Two" }
    )

    assert_equal %w[First Second], results.map { |r| PersonDetail.find(r[:detail_id]).first_name }
  end

  test "an entry missing last_name errors in its own slot only" do
    results = results_for(
      { first_name: "Ada", last_name: "Lovelace" },
      { first_name: "Onlyfirst" },
      { first_name: "Grace", last_name: "Hopper" }
    )

    assert_equal "first_name and last_name are required", results[1][:error]
    assert results[0][:person_id].present?
    assert results[2][:person_id].present?
    assert_equal 2, PersonDetail.where(source_processing_report: @report).count
  end

  test "accepts string keys as they arrive from JSON" do
    results = results_for({ "first_name" => "Ada", "last_name" => "Lovelace" })

    assert_equal "Ada", PersonDetail.find(results[0][:detail_id]).first_name
  end

  test "an empty array is rejected without touching the database" do
    assert_no_difference "Person.count" do
      assert_equal "people must be a non-empty array", @tool.execute(people: [])[:error]
    end
  end

  test "an existing person is reused rather than duplicated" do
    first = results_for({ first_name: "Ada", last_name: "Lovelace" })[0]

    assert_no_difference "Person.count" do
      second = results_for({ first_name: "ada", last_name: "LOVELACE" })[0]

      assert_equal first[:person_id], second[:person_id]
      assert_not second[:created]
    end
  end

  test "current_detail points at the last detail written for that person" do
    results = results_for(
      { first_name: "Ada", last_name: "Lovelace" },
      { first_name: "Ada", last_name: "Lovelace", confidence_tenths: 950 }
    )

    person = Person.find(results[1][:person_id])
    assert_equal results[1][:detail_id], person.current_detail_id
    assert_equal 950, person.current_detail.confidence_tenths
  end

  test "confidence clamps per entry and defaults when omitted" do
    results = results_for(
      { first_name: "High", last_name: "One", confidence_tenths: 5000 },
      { first_name: "Low", last_name: "Two", confidence_tenths: -20 },
      { first_name: "Default", last_name: "Three" }
    )

    assert_equal 1000, PersonDetail.find(results[0][:detail_id]).confidence_tenths
    assert_equal 0, PersonDetail.find(results[1][:detail_id]).confidence_tenths
    assert_equal 800, PersonDetail.find(results[2][:detail_id]).confidence_tenths
  end

  test "additional_attributes drops non-scalar values per entry" do
    results = results_for(
      { first_name: "Ada", last_name: "Lovelace",
        additional_attributes: { "role" => "mathematician", "nested" => [ 1, 2 ], "rank" => 1 } }
    )

    attrs = PersonDetail.find(results[0][:detail_id]).additional_attributes
    assert_equal({ "role" => "mathematician", "rank" => 1 }, attrs)
  end
end
