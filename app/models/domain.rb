class Domain < ApplicationRecord
  has_many :sources, dependent: :restrict_with_error

  validates :host, presence: true, uniqueness: { case_sensitive: false }
  validates :min_crawl_delay_seconds,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 },
            allow_nil: true

  before_validation :normalize_host

  private

  def normalize_host
    self.host = host.to_s.downcase.strip if host.present?
  end
end
