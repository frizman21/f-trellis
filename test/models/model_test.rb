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
    xai       = build_model(provider: "xai",       model_id: "sel-xai",       last_seen_at: now)
    other     = build_model(provider: "openrouter", model_id: "sel-other",    last_seen_at: now)
    retired   = build_model(provider: "anthropic", model_id: "sel-retired",   last_seen_at: now - 1.day)

    selectable = Model.selectable
    assert_includes selectable, anthropic
    assert_includes selectable, openai
    assert_includes selectable, xai
    assert_not_includes selectable, other
    assert_not_includes selectable, retired
  end

  # The risk in widening this list is widening it too far. Azure in particular:
  # it serves ids OpenAI also serves — gpt-4.1 is in the registry under both —
  # and a lookup that reached it produced a configuration error that read as a
  # broken environment rather than a model that was never callable (#78).
  test "adding xai did not make every provider in the registry pickable" do
    now = Time.current
    unwanted = %w[azure bedrock deepseek gemini mistral openrouter perplexity vertexai].map do |provider|
      build_model(provider: provider, model_id: "sel-#{provider}", last_seen_at: now)
    end

    unwanted.each do |model|
      assert_not_includes Model.selectable, model, "#{model.provider} should not be pickable"
    end
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

  test "deprecated and disabled models are out of circulation" do
    now = Time.current
    fine       = build_model(provider: "openai", model_id: "circ-fine", last_seen_at: now)
    deprecated = build_model(provider: "openai", model_id: "circ-deprecated", last_seen_at: now)
    disabled   = build_model(provider: "openai", model_id: "circ-disabled", last_seen_at: now)
    deprecated.update!(is_deprecated: true)
    disabled.update!(is_disabled: true)

    assert_includes Model.selectable, fine
    assert_not_includes Model.selectable, deprecated
    assert_not_includes Model.selectable, disabled

    assert_not deprecated.chat_capable?
    assert_not disabled.chat_capable?
    assert fine.chat_capable?

    assert_equal [ deprecated, disabled ].sort_by(&:id),
                 Model.current.out_of_circulation.sort_by(&:id)
  end

  # The flags are evidence from a real call; the modality metadata is the
  # provider's description of itself. When they disagree the call wins.
  test "the flags outrank a declared text modality" do
    model = with_modalities("gpt-flagged", [ "text" ])
    assert_nil model.capability_flag

    model.update!(is_deprecated: true)
    assert_equal "deprecated", model.capability_flag

    model.update!(is_deprecated: false, is_disabled: true)
    assert_equal "disabled", model.capability_flag
  end

  test "deprecation_reason_for recognises the errors that mean the model is finished" do
    assert_equal "deprecated by the provider",
                 Model.deprecation_reason_for("The model `gpt-5.1-codex` has been deprecated, learn more here...")
    assert_equal "not served by the chat completions endpoint",
                 Model.deprecation_reason_for("This is not a chat model and thus not supported in the v1/chat/completions endpoint.")
    assert_equal "unknown to this account",
                 Model.deprecation_reason_for("The model `gpt-5.3-codex-spark` does not exist or you do not have access to it.")
    assert_equal "unknown to this account", Model.deprecation_reason_for("model_not_found")
  end

  test "deprecation_reason_for leaves failures a retry could survive alone" do
    assert_nil Model.deprecation_reason_for("Rate limit reached for model `gpt-5-nano`")
    assert_nil Model.deprecation_reason_for("The server had an error while processing your request")
    assert_nil Model.deprecation_reason_for(Timeout::Error.new("execution expired"))
  end

  test "deprecate_for! sets the flag only on a permanent failure" do
    model = build_model(provider: "openai", model_id: "dep-target", last_seen_at: Time.current)

    assert_nil model.deprecate_for!(StandardError.new("Rate limit reached"))
    assert_not model.reload.is_deprecated?

    reason = model.deprecate_for!(StandardError.new("The model `dep-target` has been deprecated"))
    assert_equal "deprecated by the provider", reason
    assert model.reload.is_deprecated?
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
