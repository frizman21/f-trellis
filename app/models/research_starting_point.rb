class ResearchStartingPoint < ApplicationRecord
  FREQUENCIES = %w[monthly weekly daily four_times_daily one_off].freeze

  FREQUENCY_LABELS = {
    "monthly"          => "Monthly",
    "weekly"           => "Weekly",
    "daily"            => "Daily",
    "four_times_daily" => "Four times daily",
    "one_off"          => "One-off"
  }.freeze

  validates :url, presence: true
  validates :frequency, inclusion: { in: FREQUENCIES }

  scope :enabled,  -> { where(is_enabled: true) }
  scope :disabled, -> { where(is_enabled: false) }

  def frequency_label
    FREQUENCY_LABELS[frequency] || frequency
  end
end
