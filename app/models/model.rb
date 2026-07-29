class Model < ApplicationRecord
  acts_as_model

  # Providers whose models this app actually lets you pick.
  SELECTABLE_PROVIDERS = %w[anthropic openai].freeze

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
end
