require "test_helper"

class CrawlPacerTest < ActiveSupport::TestCase
  # A fake clock and sleeper, so nothing here actually waits. A suite that
  # really slept would take minutes and would then stop being run.
  def build_pacer
    @now = 0.0
    @slept = []

    pacer = CrawlPacer.new(
      clock: -> { @now },
      sleeper: ->(seconds) { @slept << seconds; @now += seconds }
    )

    [ pacer, -> { @slept } ]
  end

  def advance(seconds)
    @now += seconds
  end

  test "the first request to a host does not wait" do
    pacer, slept = build_pacer

    pacer.wait_for("example.com", 5)

    assert_empty slept.call
  end

  test "a second request within the interval waits only for the remainder" do
    pacer, slept = build_pacer

    pacer.wait_for("example.com", 5)
    advance(2)
    pacer.wait_for("example.com", 5)

    assert_equal [ 3.0 ], slept.call
  end

  test "a second request after the interval has passed does not wait" do
    pacer, slept = build_pacer

    pacer.wait_for("example.com", 5)
    advance(9)
    pacer.wait_for("example.com", 5)

    assert_empty slept.call
  end

  test "requests to different hosts do not wait on each other" do
    pacer, slept = build_pacer

    pacer.wait_for("example.com", 5)
    pacer.wait_for("other.com", 5)

    assert_empty slept.call
  end

  test "a zero or nil delay never waits" do
    pacer, slept = build_pacer

    pacer.wait_for("example.com", 0)
    pacer.wait_for("example.com", 0)
    pacer.wait_for("example.com", nil)

    assert_empty slept.call
  end

  # Domain already downcases its host; the pacer must agree or one site gets
  # two budgets.
  test "hosts are compared case-insensitively" do
    pacer, slept = build_pacer

    pacer.wait_for("Example.COM", 5)
    advance(1)
    pacer.wait_for("example.com", 5)

    assert_equal [ 4.0 ], slept.call
  end

  test "waiting counts from the last request, so a run of pages paces evenly" do
    pacer, slept = build_pacer

    3.times { pacer.wait_for("example.com", 2) }

    assert_equal [ 2.0, 2.0 ], slept.call
  end
end
