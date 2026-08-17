# One fetch the system performed, and what came back. Every fetch leaves a
# record — a crawl's pages, a page somebody fetched by hand, and the fetch a
# new source queues for itself — because the difference between them is which
# button started them, not what the remote server experienced.
#
# The domain is filled from the URL here rather than at the call site, so the
# invariant holds for seeds and tests as well as for FetchSourceJob.
class FetchRecord < ApplicationRecord
  # Why the attempt ended as it did. A null status_code alone cannot tell these
  # apart, which is the whole reason this column exists.
  #
  #   ok           fetched and stored
  #   http_error   the server answered with an error status
  #   unusable     we reached the server and refused what it sent — a PDF, a
  #                redirect we would not follow — so the status may be 200
  #   no_response  the request produced nothing at all: timeout, DNS, refused
  #   skipped      no request was made; the page was already held
  OUTCOMES = %w[ok http_error unusable no_response skipped].freeze

  # What started the fetch. Kept because the log used to answer "was this a
  # crawl?" by construction, and recording everything would otherwise lose it.
  #
  #   crawl    a page CrawlJob processed
  #   manual   the "Fetch content" button on a source page
  #   initial  the unforced fetch a newly created source queues for itself
  TRIGGERS = %w[crawl manual initial].freeze

  belongs_to :domain

  validates :url, presence: true
  validates :outcome, inclusion: { in: OUTCOMES }
  validates :trigger, inclusion: { in: TRIGGERS }

  scope :recent, -> { order(created_at: :desc) }

  before_validation :assign_domain_from_url

  def succeeded?
    outcome == "ok"
  end

  private

  def assign_domain_from_url
    return if domain.present?

    self.domain = Domain.for_url(url)
  end
end
