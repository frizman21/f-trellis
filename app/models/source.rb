require "uri"

class Source < ApplicationRecord
  STATUSES = %w[new in_work complete failed].freeze

  belongs_to :domain
  has_many :source_data, dependent: :destroy
  has_many :source_processing_reports, dependent: :destroy

  validates :url, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :promotable_pending, -> { where(is_promotable: true, is_fixtured: false) }

  before_validation :assign_domain_from_url

  private

  def assign_domain_from_url
    return if domain.present?
    return if url.blank?

    host = URI.parse(url).host&.downcase
    return if host.blank?

    self.domain = Domain.find_or_create_by!(host: host)
  rescue URI::InvalidURIError
    nil
  end
end
