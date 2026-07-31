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
  has_many :learning_set_sources, dependent: :destroy
  has_many :learning_sets, through: :learning_set_sources

  validates :url, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :promotable_pending, -> { where(is_promotable: true, is_fixtured: false) }

  before_validation :assign_domain_from_url

  # A page is identified by its URL. Two people pasting the same link must land
  # on the same row — a second row would split the page's fetched content and
  # its processing history in half. Returns nil when the text is not a usable
  # web address.
  def self.for_url(raw)
    normalized = normalize_url(raw)
    return nil if normalized.blank?

    find_by(url: normalized) || create!(url: normalized)
  end

  # Tolerates what people actually paste: surrounding space, a missing scheme,
  # a trailing #fragment that names a spot on the page rather than a page.
  def self.normalize_url(raw)
    candidate = raw.to_s.strip
    return nil if candidate.blank?

    candidate = "https://#{candidate}" unless candidate.match?(%r{\A[a-z][a-z0-9+.\-]*://}i)
    uri = URI.parse(candidate)
    return nil unless uri.is_a?(URI::HTTP) && uri.host.present?

    uri.fragment = nil
    uri.to_s
  rescue URI::InvalidURIError
    nil
  end

  # The most recent payload fetched for this page. A re-fetch supersedes earlier
  # copies rather than replacing them, so "latest" is what anything reading the
  # page should use.
  def latest_datum
    source_data.order(:created_at).last
  end

  # The page's extracted text. Models get this, not the markup — see
  # ContentExtractor for why.
  def latest_text
    latest_datum&.text
  end

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
