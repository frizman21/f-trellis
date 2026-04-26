require "test_helper"

class ResearchStartingPointTest < ActiveSupport::TestCase
  test "valid with url and allowed frequency" do
    rsp = ResearchStartingPoint.new(url: "https://example.com", frequency: "weekly")
    assert rsp.valid?, rsp.errors.full_messages.to_sentence
  end

  test "invalid without url" do
    rsp = ResearchStartingPoint.new(frequency: "weekly")
    assert_not rsp.valid?
    assert_includes rsp.errors[:url], "can't be blank"
  end

  test "invalid frequency rejected" do
    rsp = ResearchStartingPoint.new(url: "https://example.com", frequency: "hourly")
    assert_not rsp.valid?
    assert_includes rsp.errors[:frequency], "is not included in the list"
  end

  test "all FREQUENCIES are accepted" do
    ResearchStartingPoint::FREQUENCIES.each do |freq|
      rsp = ResearchStartingPoint.new(url: "https://example.com/#{freq}", frequency: freq)
      assert rsp.valid?, "expected #{freq} to be valid: #{rsp.errors.full_messages.to_sentence}"
    end
  end

  test "frequency_label humanizes underscored values" do
    rsp = ResearchStartingPoint.new(frequency: "four_times_daily")
    assert_equal "Four times daily", rsp.frequency_label
  end

  test "is_enabled defaults to true and last_run_at to nil" do
    rsp = ResearchStartingPoint.create!(url: "https://example.com/defaults", frequency: "daily")
    assert_equal true, rsp.is_enabled
    assert_nil rsp.last_run_at
  end

  test "enabled and disabled scopes partition rows" do
    enabled  = ResearchStartingPoint.create!(url: "https://example.com/e", frequency: "daily",  is_enabled: true)
    disabled = ResearchStartingPoint.create!(url: "https://example.com/d", frequency: "weekly", is_enabled: false)

    assert_includes     ResearchStartingPoint.enabled,  enabled
    assert_not_includes ResearchStartingPoint.enabled,  disabled
    assert_includes     ResearchStartingPoint.disabled, disabled
    assert_not_includes ResearchStartingPoint.disabled, enabled
  end
end
