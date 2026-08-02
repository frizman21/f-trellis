# A URL pattern whose matches are never turned into a Source by link
# extraction. Hacker News is the motivating case: the front page is worth
# reading, the thousands of `item?id=...` comment pages behind it are not, and
# without a rule a crawl spends its whole page budget on them.
#
# Scoped deliberately to *link extraction* — CrawlJob and the "Extract links"
# action. A URL entered by hand, or added to a learning set, is still created:
# asking for a page directly is a decision, and a list of patterns should not
# quietly overrule it.
class SourceExclusion < ApplicationRecord
  validates :pattern, presence: true, uniqueness: { case_sensitive: false }
  validate :pattern_resolves_to_a_url

  before_validation :normalize_pattern

  scope :enabled, -> { where(is_enabled: true) }
  scope :ordered, -> { order(:pattern) }

  # Splits `urls` into the ones link extraction should keep and the ones a
  # pattern rejected. Patterns are read once and passed back in by the caller
  # when filtering several lists from the same page, so a crawl does not query
  # per list.
  def self.partition_urls(urls, patterns = enabled.to_a)
    return [ urls, [] ] if patterns.empty?

    urls.partition { |url| patterns.none? { |exclusion| exclusion.matches?(url) } }
  end

  # `url` is matched in the absolute form link extraction produces, which is
  # what makes a pattern written as an absolute URL exclude the relative hrefs
  # on that host too: `/item?id=1` on news.ycombinator.com has already been
  # resolved against its page before it reaches here.
  def matches?(url)
    candidate = Source.normalize_url(url)
    return false if candidate.blank?

    regexp.match?(candidate)
  end

  # How many sources already in the database this pattern covers. Shown on the
  # index because a pattern that matches nothing is usually a typo rather than
  # a rule that has not fired yet — the count is the fastest way to see which.
  def matching_source_count
    Source.where("url ILIKE ?", like_pattern).count
  end

  # `*` stands for any run of characters; everything else is literal. Anchored
  # at both ends, so `https://example.com/a` does not match `.../a/b` unless it
  # says so. Case-insensitive: the host half of a URL is anyway, and a rule
  # that misses because of a capital letter is worse than one that is broad.
  def regexp
    @regexp ||= {}
    @regexp[pattern] ||= begin
      body = pattern.to_s.split("*", -1).map { |literal| Regexp.escape(literal) }.join(".*")
      Regexp.new("\\A#{body}\\z", Regexp::IGNORECASE)
    end
  end

  private

  # The same pattern as a SQL LIKE argument, for counting rows in the database
  # rather than in Ruby. LIKE's own metacharacters are escaped first so a `%`
  # in a query string stays literal; `*` is not special to LIKE, so it survives
  # escaping and can be translated afterwards.
  def like_pattern
    pattern.to_s.gsub(/[\\%_]/) { |char| "\\#{char}" }.gsub("*", "%")
  end

  # Held to the same normalization as a Source's url — a missing scheme filled
  # in, a fragment dropped — because that is the form the links being matched
  # arrive in. A pattern that keeps its `#section` would match nothing at all.
  def normalize_pattern
    return if pattern.blank?

    self.pattern = Source.normalize_url(pattern) || pattern.to_s.strip
  end

  def pattern_resolves_to_a_url
    return if pattern.blank?
    return if Source.normalize_url(pattern).present?

    errors.add(:pattern, "must be a URL, such as https://news.ycombinator.com/item?id=*")
  end
end
