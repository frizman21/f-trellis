# One edge in the page-link graph: `from_source`'s content contained a link to
# `to_source`. Written by CrawlJob and by the "Extract links" action, which
# record an edge for every link they resolve to a known source — including
# links to sources that already existed.
class SourceLink < ApplicationRecord
  belongs_to :from_source, class_name: "Source", inverse_of: :outbound_links
  belongs_to :to_source,   class_name: "Source", inverse_of: :inbound_links
  # Which snapshot of from_source the link was read out of. Optional: rows
  # written before this was tracked have none, and the datum they came from is
  # not recoverable.
  belongs_to :source_datum, optional: true

  validates :to_source_id, uniqueness: { scope: :from_source_id }
  validate :not_self_referential

  # Idempotent: safe to call again when a page is re-crawled or re-extracted.
  # Returns nil rather than raising for a self-link or a missing end.
  #
  # `datum` is recorded only when the edge is created, so it names the snapshot
  # that *first* found the link. Assigning it on every call would quietly turn
  # the column into "most recent finder" the first time a page is re-crawled,
  # which is a different fact and not the one the graph wants.
  def self.record(from:, to:, datum: nil)
    return nil if from.nil? || to.nil? || from.id == to.id

    find_or_create_by!(from_source: from, to_source: to) do |link|
      link.source_datum = datum
    end
  rescue ActiveRecord::RecordNotUnique
    find_by(from_source: from, to_source: to)
  end

  private

  def not_self_referential
    return if from_source_id.blank? || from_source_id != to_source_id

    errors.add(:to_source, "cannot be the same source it links from")
  end
end
