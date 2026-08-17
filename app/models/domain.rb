class Domain < ApplicationRecord
  has_many :sources, dependent: :restrict_with_error
  # History of what the crawler fetched from this site. Destroyed with the
  # domain rather than restricting it: a log is about the domain and means
  # nothing without it, unlike a source, which is content worth protecting.
  has_many :fetch_records, dependent: :destroy

  # The domain a URL belongs to, created if this is the first time the host has
  # been seen. The single place a host becomes a Domain — two copies of this
  # would eventually disagree and produce two rows for one host.
  def self.for_url(url)
    return nil if url.blank?

    host = URI.parse(url.to_s).host&.downcase
    return nil if host.blank?

    find_or_create_by!(host: host)
  rescue URI::InvalidURIError
    nil
  end

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
