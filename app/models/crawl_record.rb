# One page the crawler processed, and when. The log of what a crawl actually
# did, as distinct from the sources it produced — a page that was fetched and
# yielded nothing still happened.
#
# The domain is filled from the URL here rather than at the call site, so the
# invariant holds for seeds and tests as well as for CrawlJob.
class CrawlRecord < ApplicationRecord
  belongs_to :domain

  validates :url, presence: true

  before_validation :assign_domain_from_url

  private

  def assign_domain_from_url
    return if domain.present?

    self.domain = Domain.for_url(url)
  end
end
