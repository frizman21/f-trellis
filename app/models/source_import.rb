# One paste of URLs, and what became of it.
#
# The URLs arrive out of a spreadsheet a couple of thousand at a time, which is
# too many for the request that submits them and far too many to enter one at a
# time through sources#new. This holds the text that was pasted, so an import is
# auditable rather than a set of counts with no provenance, and the report the
# job writes back.
class SourceImport < ApplicationRecord
  STATUSES = %w[new running complete failed].freeze

  validates :raw_urls, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :recent, -> { order(created_at: :desc) }

  # The lines a human actually typed, with the blank ones a spreadsheet paste
  # always brings along removed. One definition, so the job and the count on
  # screen can never disagree about what "submitted" meant.
  def submitted_urls
    raw_urls.to_s.lines.map(&:strip).reject(&:blank?)
  end

  def finished?
    status == "complete" || status == "failed"
  end

  def rejected_entries
    Array(rejected)
  end
end
