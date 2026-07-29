require "test_helper"

class ModelTest < ActiveSupport::TestCase
  def build_model(provider:, model_id:, last_seen_at:)
    Model.create!(provider: provider, model_id: model_id, name: model_id, last_seen_at: last_seen_at)
  end

  test "current returns only models stamped by the most recent refresh" do
    now = Time.current
    fresh   = build_model(provider: "anthropic", model_id: "fresh-1",   last_seen_at: now)
    retired = build_model(provider: "anthropic", model_id: "retired-1", last_seen_at: now - 1.day)

    assert_includes Model.current, fresh
    assert_not_includes Model.current, retired
  end

  test "current returns everything when nothing has been stamped" do
    Model.delete_all
    never_stamped = build_model(provider: "openai", model_id: "unstamped", last_seen_at: nil)

    assert_includes Model.current, never_stamped
  end

  test "selectable is limited to pickable providers and drops retired models" do
    now = Time.current
    anthropic = build_model(provider: "anthropic", model_id: "sel-anthropic", last_seen_at: now)
    openai    = build_model(provider: "openai",    model_id: "sel-openai",    last_seen_at: now)
    other     = build_model(provider: "openrouter", model_id: "sel-other",    last_seen_at: now)
    retired   = build_model(provider: "anthropic", model_id: "sel-retired",   last_seen_at: now - 1.day)

    selectable = Model.selectable
    assert_includes selectable, anthropic
    assert_includes selectable, openai
    assert_not_includes selectable, other
    assert_not_includes selectable, retired
  end

  test "selectable is ordered by provider then model_id" do
    now = Time.current
    build_model(provider: "openai",    model_id: "b-model", last_seen_at: now)
    build_model(provider: "anthropic", model_id: "z-model", last_seen_at: now)
    build_model(provider: "anthropic", model_id: "a-model", last_seen_at: now)

    ordered = Model.selectable.pluck(:provider, :model_id)
    assert_equal ordered.sort, ordered
  end
end
