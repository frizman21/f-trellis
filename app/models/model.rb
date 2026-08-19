class Model < ApplicationRecord
  acts_as_model

  # Where to reach this model, for the ones no provider refresh discovered.
  # Nil for every model that came from OpenAI's or Anthropic's own registry.
  belongs_to :model_endpoint, optional: true

  # A model is identified by its provider and its id, and the registry has a
  # unique index saying so. Stated here too, because a custom model is the one
  # kind that is typed in by hand: without it a repeated id is a 500 rather than
  # a message on the form.
  validates :model_id, uniqueness: { scope: :provider }

  # Providers whose models this app actually lets you pick. `custom_endpoint` is
  # the one that is not a provider in the world — it is this application's name
  # for "reachable at an address somebody entered".
  SELECTABLE_PROVIDERS = %w[anthropic custom_endpoint openai].freeze

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

  # Messages that mean "this model will never answer", as the providers phrase
  # them. Matched on the message rather than the exception class because RubyLLM
  # raises BadRequestError for both a dead model and a malformed request, and the
  # class alone cannot tell one from the other.
  #
  # Deliberately narrow, and in the opposite direction from NON_CHAT_ID_PATTERNS
  # above: anything unrecognised deprecates nothing. Retiring a working model by
  # accident costs more than letting a broken one fail twice, and the edit form
  # covers whatever the table misses.
  DEPRECATION_PATTERNS = {
    /has been deprecated/i => "deprecated by the provider",
    /not a chat model/i => "not served by the chat completions endpoint",
    /does not exist or you do not have access/i => "unknown to this account",
    /model_not_found/i => "unknown to this account"
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
    # A custom model is never stamped, because no provider was asked about it —
    # it is current because somebody entered it. Without the exemption every
    # custom model would fall out of every picker the first time the registry
    # was refreshed.
    cutoff ? where(last_seen_at: cutoff..).or(where.not(model_endpoint_id: nil)) : all
  }

  # Models nothing should spend money on: retired by their provider, or switched
  # off here.
  scope :usable, -> { where(is_deprecated: false, is_disabled: false) }
  scope :out_of_circulation, -> { where(is_deprecated: true).or(where(is_disabled: true)) }

  # The registry as offered in model pickers.
  scope :selectable, -> { current.usable.where(provider: SELECTABLE_PROVIDERS).order(:provider, :model_id) }

  # Served from an address somebody entered rather than from a provider's own
  # registry. The endpoint is what carries the URL and the credential.
  def custom? = model_endpoint_id.present?

  # Out of circulation, either way round. Both flags mean "do not run this"; they
  # are separate columns because they are cleared by different people.
  def unusable?
    is_deprecated? || is_disabled?
  end

  # Why this model cannot read a page and write a reply, or nil when nothing is
  # wrong with it. A short phrase, meant to be shown next to the checkbox.
  #
  # The two flags come first: a model the provider refused, or one somebody
  # switched off, is settled regardless of what its metadata claims. Then the
  # declared output modality; the id patterns only get a say when the provider
  # declared nothing. That last ordering is what keeps `gpt-3.5-turbo-0125` —
  # empty modalities, unmistakably a chat model — unflagged.
  def capability_flag
    return "deprecated" if is_deprecated?
    return "disabled" if is_disabled?

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

  # Marks this model deprecated when `error` is one a retry could never fix, and
  # returns the reason; nil, and no change, for anything else.
  #
  # Called from the rescue of anything that asks a model to do work. A failed
  # call is the only evidence there is that a listed model is not a usable one —
  # nothing in the registry metadata distinguishes them — so the run that trips
  # over it is what takes it out of circulation, rather than the next N pages
  # tripping over it in turn.
  def deprecate_for!(error)
    reason = self.class.deprecation_reason_for(error)
    return nil if reason.nil?

    unless is_deprecated?
      update!(is_deprecated: true)
      Rails.logger.warn("Model #{provider}/#{model_id} deprecated: #{reason} (#{error.class}: #{error.message})")
    end

    reason
  end

  # Why this error means the model is finished, or nil when it is the kind of
  # failure a later call might survive — a rate limit, a timeout, an overloaded
  # provider. Accepts an exception or a message.
  def self.deprecation_reason_for(error)
    message = error.respond_to?(:message) ? error.message.to_s : error.to_s
    _, reason = DEPRECATION_PATTERNS.find { |pattern, _| pattern.match?(message) }
    reason
  end

  private

  def declared_output_modalities
    Array(modalities.is_a?(Hash) ? modalities["output"] : nil).map(&:to_s)
  end
end
