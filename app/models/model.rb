class Model < ApplicationRecord
  acts_as_model

  # Providers whose models this app actually lets you pick.
  SELECTABLE_PROVIDERS = %w[anthropic openai].freeze

  # Reasons drawn from a *declared* output modality. When a provider says what
  # comes out of a model, that settles it.
  OUTPUT_MODALITY_FLAGS = {
    "image" => "outputs images, not text",
    "embeddings" => "returns embeddings",
    "audio" => "speech model",
    "video" => "outputs video, not text",
    "moderation" => "classifier, not a chat model"
  }.freeze

  # A stopgap for the third of the registry that declares no modalities at all.
  # These are id patterns, not a taxonomy: the moment a provider ships proper
  # metadata for `whisper-1`, the entry matching it stops mattering and this
  # list should shrink. Deliberately narrow — anything not recognised here is
  # treated as a chat model, because guessing wrong in that direction only shows
  # one extra checkbox, while guessing wrong the other way hides a usable model.
  NON_CHAT_ID_PATTERNS = {
    /(\A|-)tts(-|\z)/ => "speech model",
    /whisper|transcribe/ => "speech-to-text model",
    /embedding/ => "returns embeddings",
    /\Adall-e|gpt-image/ => "outputs images, not text",
    /\Asora/ => "outputs video, not text",
    /moderation/ => "classifier, not a chat model",
    /realtime|\Agpt-audio/ => "realtime audio model"
  }.freeze

  # Ids carry their release date as a suffix — `-2025-08-07` at OpenAI,
  # `-20241022` at Anthropic — and `-latest` names the same weights again.
  # Stripping those yields the key that collapses an alias and its snapshots.
  SNAPSHOT_SUFFIX = /-(?:\d{4}-\d{2}-\d{2}|\d{8}|latest)\z/

  # Rows stamped by the most recent refresh. RefreshModelsJob stamps every model
  # a provider returned with one shared timestamp, so models a provider has
  # retired keep an older `last_seen_at` and drop out. Rows are never deleted —
  # Chat/SourceProcessingReport/Skill records referencing a retired model still
  # resolve.
  scope :current, -> {
    cutoff = unscoped.maximum(:last_seen_at)
    cutoff ? where(last_seen_at: cutoff..) : all
  }

  # The registry as offered in model pickers.
  scope :selectable, -> { current.where(provider: SELECTABLE_PROVIDERS).order(:provider, :model_id) }

  # Why this model cannot read a page and write a reply, or nil when nothing is
  # wrong with it. A short phrase, meant to be shown next to the checkbox.
  #
  # Declared output modality first; the id patterns only get a say when the
  # provider declared nothing. That ordering is what keeps `gpt-3.5-turbo-0125`
  # — empty modalities, unmistakably a chat model — unflagged.
  def capability_flag
    outputs = declared_output_modalities

    if outputs.any?
      return nil if outputs.include?("text")

      return OUTPUT_MODALITY_FLAGS.fetch(outputs.first) { "outputs #{outputs.to_sentence}, not text" }
    end

    _, reason = NON_CHAT_ID_PATTERNS.find { |pattern, _| pattern.match?(model_id.to_s) }
    reason
  end

  # Can this model be asked to do an evaluation's job? Fails toward inclusion:
  # silence in the metadata is not evidence against a model, so one that nothing
  # recognises counts as capable.
  def chat_capable?
    capability_flag.nil?
  end

  # Standard input price in dollars per million text tokens, or nil when the
  # model carries no pricing. Prices span three orders of magnitude across the
  # registry, so this is the number that decides what a run costs.
  def input_price_per_million
    pricing&.dig("text_tokens", "standard", "input_per_million")&.to_f
  end

  # The id with any release-date or `-latest` suffix removed, e.g.
  # `gpt-5-nano-2025-08-07` and `gpt-5-nano` both give `gpt-5-nano`. Two models
  # sharing this key are the same weights billed twice.
  def snapshot_key
    model_id.to_s.sub(SNAPSHOT_SUFFIX, "")
  end

  # True for a dated or `-latest` id rather than the bare alias.
  def dated_snapshot?
    SNAPSHOT_SUFFIX.match?(model_id.to_s)
  end

  private

  def declared_output_modalities
    Array(modalities.is_a?(Hash) ? modalities["output"] : nil).map(&:to_s)
  end
end
