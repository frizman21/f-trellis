require "uri"

class Source < ApplicationRecord
  # nullify would orphan a citation and destroy would delete recorded knowledge,
  # so a source that is still cited cannot be deleted at all. Losing the page a
  # fact came from must not lose the fact.
  has_many :entity_extraction_runs, dependent: :restrict_with_error
  has_many :relationship_extraction_runs, dependent: :restrict_with_error
  has_many :entity_attribute_value_extraction_runs, dependent: :restrict_with_error
  has_many :relationship_type_value_extraction_runs, dependent: :restrict_with_error

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

  # Which projects care about this page. Destroying a source would take its
  # joins, though a cited source cannot be destroyed at all.
  has_many :project_sources, dependent: :destroy
  has_many :projects, through: :project_sources

  has_many :source_data, dependent: :destroy
  has_many :source_processing_reports, dependent: :destroy
  has_many :learning_set_sources, dependent: :destroy
  has_many :learning_sets, through: :learning_set_sources
  has_many :skill_evaluation_results, dependent: :destroy

  validates :url, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :promotable_pending, -> { where(is_promotable: true, is_fixtured: false) }

  # A page that asked not to be kept as a retrievable record. Still readable in
  # the app; simply not turned into knowledge-graph facts.
  def indexable?
    !is_noindex
  end

  before_validation :assign_domain_from_url

  # A page is identified by its URL. Two people pasting the same link must land
  # on the same row — a second row would split the page's fetched content and
  # its processing history in half. Returns nil when the text is not a usable
  # web address.
  def self.for_url(raw)
    normalized = normalize_url(raw)
    return nil if normalized.blank?

    existing = find_by(url: normalized)
    return existing if existing

    create!(url: normalized).tap(&:queue_initial_fetch)
  end

  # Start the download for a page somebody deliberately asked for.
  #
  # Unforced on purpose: FetchSourceJob returns unless the status is still
  # `new`, so a queued fetch can never clobber content a crawl or a manual
  # re-fetch produced in the meantime.
  #
  # Called explicitly rather than from an `after_create` callback. A callback
  # would fire on all four creation paths and two of them are wrong: CrawlJob
  # fetches the children it creates with `perform_now`, so a callback would race
  # its own crawl, and link extraction can create hundreds of rows from one
  # click and would turn that click into hundreds of outbound requests.
  def queue_initial_fetch
    FetchSourceJob.perform_later(self, trigger: "initial")
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

    self.domain = Domain.for_url(url)
  end
end
