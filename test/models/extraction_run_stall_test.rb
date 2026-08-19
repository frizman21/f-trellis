require "test_helper"

# Telling a run whose worker died from one that is still working. The threshold
# is derived from RubyLLM's own limits rather than chosen, so the two cannot
# disagree.
class ExtractionRunStallTest < ActiveSupport::TestCase
  setup do
    @project = projects(:apollo)
    @source = sources(:one)
    @model = Model.create!(provider: "anthropic", model_id: "claude-test", name: "Claude Test",
                           last_seen_at: Time.current)
  end

  def run_record(status: "running", started_at: Time.current, **attrs)
    ExtractionRun.create!({ project: @project, source: @source, model: @model,
                            status: status, started_at: started_at }.merge(attrs))
  end

  # --- the threshold ---------------------------------------------------------

  test "the give-up point is RubyLLM's own, not a number of ours" do
    expected = RubyLLM.config.request_timeout * (RubyLLM.config.max_retries + 1)

    assert_equal expected, ExtractionRun.gives_up_after.to_i
    assert_equal expected + ExtractionRun::GRACE.to_i, ExtractionRun.stall_after.to_i
  end

  # A hardcoded threshold would be wrong the first time anybody tuned the config.
  test "lowering RubyLLM's timeout lowers the threshold with it" do
    original = RubyLLM.config.request_timeout
    RubyLLM.config.request_timeout = 10

    assert_equal 10 * (RubyLLM.config.max_retries + 1), ExtractionRun.gives_up_after.to_i
  ensure
    RubyLLM.config.request_timeout = original
  end

  # --- which side of it ------------------------------------------------------

  test "a run inside the threshold is live" do
    run = run_record(started_at: 2.minutes.ago)

    assert run.live?
    assert_not run.stalled?
    assert_includes ExtractionRun.live, run
    assert_not_includes ExtractionRun.stalled, run
  end

  test "a run past the threshold is stalled" do
    run = run_record(started_at: (ExtractionRun.stall_after + 1.minute).ago)

    assert run.stalled?
    assert_not run.live?
    assert_includes ExtractionRun.stalled, run
    assert_not_includes ExtractionRun.live, run
  end

  # Queued and never picked up is the same failure with no started_at to measure
  # from.
  test "a run that never started is measured from when it was queued" do
    run = run_record(status: "pending", started_at: nil)
    run.update_columns(created_at: (ExtractionRun.stall_after + 1.minute).ago)

    assert run.reload.stalled?
    assert_includes ExtractionRun.stalled, run
  end

  test "a finished run is neither live nor stalled, however old" do
    [ "complete", "failed" ].each do |status|
      run = run_record(status: status, started_at: 3.hours.ago, completed_at: 2.hours.ago)

      assert_not run.stalled?, "#{status} should not be stalled"
      assert_not run.live?, "#{status} should not be live"
      assert_not_includes ExtractionRun.stalled, run
      assert_not_includes ExtractionRun.live, run
    end
  end

  # in_flight is what anything wanting "not yet finished" still wants; only the
  # question "may I start another?" narrows.
  test "in_flight still counts a stalled run" do
    run = run_record(started_at: 3.hours.ago)

    assert_includes ExtractionRun.in_flight, run
  end

  # --- elapsed ---------------------------------------------------------------

  test "elapsed runs to now while working and stops when it finished" do
    working = run_record(started_at: 5.minutes.ago)

    assert_in_delta 300, working.elapsed, 5

    finished = run_record(status: "complete", started_at: 10.minutes.ago,
                          completed_at: 8.minutes.ago)

    assert_in_delta 120, finished.elapsed, 5
  end
end
