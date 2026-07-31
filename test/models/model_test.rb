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

  def with_modalities(model_id, outputs)
    Model.create!(provider: "openai", model_id: model_id, name: model_id,
                  last_seen_at: Time.current,
                  modalities: { "input" => [ "text" ], "output" => outputs })
  end

  test "a model that declares text output is not flagged" do
    model = with_modalities("gpt-chatty", [ "text" ])

    assert_nil model.capability_flag
    assert model.chat_capable?
  end

  test "a model that returns embeddings is flagged" do
    model = with_modalities("text-embedding-3-small", [ "embeddings" ])

    assert_equal "returns embeddings", model.capability_flag
    assert_not model.chat_capable?
  end

  test "a model that outputs images is flagged" do
    model = with_modalities("gpt-image-1", [ "image" ])

    assert_equal "outputs images, not text", model.capability_flag
    assert_not model.chat_capable?
  end

  # The case a naive filter gets wrong: this declares nothing at all, and an
  # include-filter on "outputs text" would drop an ordinary chat model.
  test "a chat model that declares no modalities at all is not flagged" do
    model = with_modalities("gpt-3.5-turbo-0125", [])

    assert_nil model.capability_flag
    assert model.chat_capable?
  end

  test "a speech model that declares no modalities is flagged by its id" do
    assert_equal "speech model", with_modalities("tts-1", []).capability_flag
    assert_equal "speech-to-text model", with_modalities("whisper-1", []).capability_flag
  end

  test "an unrecognised output modality still says what it is" do
    model = with_modalities("weird-1", [ "hologram" ])

    assert_equal "outputs hologram, not text", model.capability_flag
  end

  test "input price reads the standard text-token rate, and is nil without pricing" do
    priced = Model.create!(provider: "openai", model_id: "priced", name: "priced",
                           last_seen_at: Time.current,
                           pricing: { "text_tokens" => { "standard" => { "input_per_million" => 0.15 } } })

    assert_in_delta 0.15, priced.input_price_per_million
    assert_nil with_modalities("unpriced", [ "text" ]).input_price_per_million
  end

  test "snapshot_key collapses dated and -latest ids onto their alias" do
    assert_equal "gpt-5-nano", build_model(provider: "openai", model_id: "gpt-5-nano-2025-08-07", last_seen_at: nil).snapshot_key
    assert_equal "claude-3-5-sonnet", build_model(provider: "anthropic", model_id: "claude-3-5-sonnet-20241022", last_seen_at: nil).snapshot_key
    assert_equal "claude-3-5-sonnet", build_model(provider: "anthropic", model_id: "claude-3-5-sonnet-latest", last_seen_at: nil).snapshot_key
    assert_equal "gpt-4.1-nano", build_model(provider: "openai", model_id: "gpt-4.1-nano", last_seen_at: nil).snapshot_key
  end

  test "dated_snapshot? is true only for the dated or -latest form" do
    assert build_model(provider: "openai", model_id: "gpt-5-nano-2025-08-07", last_seen_at: nil).dated_snapshot?
    assert build_model(provider: "anthropic", model_id: "claude-3-5-sonnet-latest", last_seen_at: nil).dated_snapshot?
    assert_not build_model(provider: "openai", model_id: "gpt-5-nano", last_seen_at: nil).dated_snapshot?
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
