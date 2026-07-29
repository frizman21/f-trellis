require "test_helper"

# Covers the staleness bookkeeping this app adds on top of RubyLLM's
# `Model.refresh!`. The refresh itself is gem code that talks to the provider
# APIs, so these tests drive `stamp_last_seen` directly with the same shape
# RubyLLM.models.all returns.
class RefreshModelsJobTest < ActiveSupport::TestCase
  # Stand-in for RubyLLM::Model::Info — only #provider and #id are read.
  ModelInfo = Struct.new(:provider, :id)

  setup { Model.delete_all }

  test "models the providers returned outrank ones they did not" do
    kept    = Model.create!(provider: "anthropic", model_id: "kept",    name: "kept",    last_seen_at: 1.day.ago)
    retired = Model.create!(provider: "anthropic", model_id: "retired", name: "retired", last_seen_at: 1.day.ago)

    RefreshModelsJob.stamp_last_seen([ModelInfo.new("anthropic", "kept")])

    assert_operator kept.reload.last_seen_at, :>, retired.reload.last_seen_at
    assert_includes Model.current, kept
    assert_not_includes Model.current, retired
  end

  test "models across providers share one timestamp so current returns all of them" do
    anthropic = Model.create!(provider: "anthropic", model_id: "a", name: "a", last_seen_at: 1.day.ago)
    openai    = Model.create!(provider: "openai",    model_id: "o", name: "o", last_seen_at: 1.day.ago)

    RefreshModelsJob.stamp_last_seen([ModelInfo.new("anthropic", "a"), ModelInfo.new("openai", "o")])

    assert_equal anthropic.reload.last_seen_at, openai.reload.last_seen_at
    assert_equal 2, Model.current.count
  end

  test "same model_id under different providers is stamped independently" do
    anthropic = Model.create!(provider: "anthropic", model_id: "shared", name: "a", last_seen_at: 1.day.ago)
    openai    = Model.create!(provider: "openai",    model_id: "shared", name: "o", last_seen_at: 1.day.ago)

    RefreshModelsJob.stamp_last_seen([ModelInfo.new("anthropic", "shared")])

    assert_operator anthropic.reload.last_seen_at, :>, openai.reload.last_seen_at
    assert_not_includes Model.current, openai
  end

  test "registry entries with no matching row are ignored" do
    Model.create!(provider: "anthropic", model_id: "known", name: "known", last_seen_at: 1.day.ago)

    assert_nothing_raised do
      RefreshModelsJob.stamp_last_seen([ModelInfo.new("anthropic", "known"), ModelInfo.new("anthropic", "not-in-db")])
    end

    assert_equal 1, Model.count
  end

  test "an empty registry leaves every model stamped as it was" do
    model = Model.create!(provider: "anthropic", model_id: "a", name: "a", last_seen_at: 1.day.ago)
    before = model.last_seen_at

    RefreshModelsJob.stamp_last_seen([])

    assert_equal before.to_i, model.reload.last_seen_at.to_i
  end
end
