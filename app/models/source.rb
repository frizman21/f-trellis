require "uri"

class Source < ApplicationRecord
  STATUSES = %w[new in_work complete failed].freeze

  belongs_to :domain
  # The source whose content linked to this one. Set when a crawl or a link
  # extraction creates the source; nil for sources entered by hand.
  belongs_to :parent_source, class_name: "Source", optional: true
  has_many :child_sources, class_name: "Source", foreign_key: :parent_source_id,
                           inverse_of: :parent_source, dependent: :nullify
  # The page-link graph: every link seen from this source's content, and every
  # link into it. Unlike parent_source these are recorded even when both ends
  # already existed.
  has_many :outbound_links, class_name: "SourceLink", foreign_key: :from_source_id,
                            inverse_of: :from_source, dependent: :destroy
  has_many :inbound_links,  class_name: "SourceLink", foreign_key: :to_source_id,
                            inverse_of: :to_source, dependent: :destroy
  has_many :links_to,    through: :outbound_links, source: :to_source
  has_many :linked_from, through: :inbound_links,  source: :from_source

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
