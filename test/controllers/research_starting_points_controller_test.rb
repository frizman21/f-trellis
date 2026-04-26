require "test_helper"

class ResearchStartingPointsControllerTest < ActionDispatch::IntegrationTest
  test "index renders" do
    get research_starting_points_path
    assert_response :success
  end

  test "new renders" do
    get new_research_starting_point_path
    assert_response :success
  end

  test "create persists a valid record" do
    assert_difference -> { ResearchStartingPoint.count }, +1 do
      post research_starting_points_path, params: {
        research_starting_point: {
          url: "https://example.com/new",
          frequency: "monthly",
          description: "Created via test."
        }
      }
    end
    assert_redirected_to research_starting_point_path(ResearchStartingPoint.last)
  end

  test "create rejects invalid frequency" do
    assert_no_difference -> { ResearchStartingPoint.count } do
      post research_starting_points_path, params: {
        research_starting_point: { url: "https://example.com/bad", frequency: "yearly" }
      }
    end
    assert_response :unprocessable_entity
  end

  test "show renders" do
    get research_starting_point_path(research_starting_points(:weekly_one))
    assert_response :success
  end

  test "edit renders" do
    get edit_research_starting_point_path(research_starting_points(:weekly_one))
    assert_response :success
  end

  test "update changes attributes" do
    rsp = research_starting_points(:weekly_one)
    patch research_starting_point_path(rsp), params: {
      research_starting_point: { frequency: "four_times_daily" }
    }
    assert_redirected_to research_starting_point_path(rsp)
    assert_equal "four_times_daily", rsp.reload.frequency
  end

  test "destroy removes the record" do
    rsp = research_starting_points(:daily_one)
    assert_difference -> { ResearchStartingPoint.count }, -1 do
      delete research_starting_point_path(rsp)
    end
    assert_redirected_to research_starting_points_path
  end

  test "update can toggle is_enabled off" do
    rsp = research_starting_points(:weekly_one)
    patch research_starting_point_path(rsp), params: {
      research_starting_point: { is_enabled: "0" }
    }
    assert_redirected_to research_starting_point_path(rsp)
    assert_equal false, rsp.reload.is_enabled
  end

  test "update does not allow setting last_run_at via params" do
    rsp = research_starting_points(:weekly_one)
    patch research_starting_point_path(rsp), params: {
      research_starting_point: { last_run_at: 1.day.ago }
    }
    assert_nil rsp.reload.last_run_at
  end
end
