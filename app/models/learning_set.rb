# A named collection of pages — the set you keep coming back to when you want to
# know whether something works. Nothing here fetches or processes: a learning set
# only says which pages belong together, so anything that needs "the pages we
# test on" can point at one instead of assembling its own list.
class LearningSet < ApplicationRecord
  has_many :learning_set_sources, dependent: :destroy
  has_many :sources, through: :learning_set_sources
  # Evaluations run against this set. Restricted rather than cascading: deleting
  # a set out from under an evaluation would leave it with results and no record
  # of which pages produced them.
  has_many :skill_evaluations, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  # Roughly four characters to a token. Good enough to tell $0.38 from $38,
  # which is the decision the number is there to inform; nothing bills on it.
  CHARS_PER_TOKEN = 4

  # What a run of this set would send, per model. `largest_page_tokens` is what
  # a model's context window has to clear — evaluation sends a page whole, so a
  # short window means that model fails for a boring reason rather than a
  # revealing one. `unfetched_pages` are pages with no content yet: they are not
  # part of the estimate and saying so is better than quietly undercounting.
  Estimate = Struct.new(:tokens, :pages, :unfetched_pages, :largest_page_tokens, keyword_init: true)

  # What adding a URL did, so the UI can say it plainly.
  Outcome = Struct.new(:status, :source, :message, keyword_init: true) do
    def added?          = status == :added
    def already_member? = status == :already_member
    def invalid?        = status == :invalid
  end

  # Adds the page at `url`, reusing the existing Source when there is one.
  # Adding a page twice is a no-op that says so — a duplicate is what the person
  # asking for it already wanted, not an error to push back on.
  def add_url(url)
    source = Source.for_url(url)

    if source.nil?
      return Outcome.new(status: :invalid, message: "#{url.to_s.truncate(80).presence || 'That'} is not a usable URL.")
    end

    add_source(source)
  end

  def add_source(source)
    if sources.include?(source)
      return Outcome.new(status: :already_member, source: source,
                         message: "#{source.url} is already in #{name}.")
    end

    learning_set_sources.create!(source: source)
    Outcome.new(status: :added, source: source, message: "Added #{source.url} to #{name}.")
  end

  # How much input one pass over this set is, as an Estimate.
  #
  # Getting the text means unzipping every stored payload and stripping its
  # markup, which is far too expensive to do while rendering a form. Cached on
  # the set's ordered content hashes: those change exactly when a page's text
  # changes, and adding or removing a page changes the list, so the key expires
  # precisely when the answer would differ.
  def estimated_input(cache: Rails.cache)
    data = latest_data
    cache.fetch([ "learning_set", id, "estimated_input", data.map(&:content_hash) ]) do
      compute_estimate(data)
    end
  end

  private

  # The newest payload per page, which is what a run would send. Ordered by
  # source so the cache key is stable across queries.
  def latest_data
    sources.sort_by(&:id).filter_map(&:latest_datum)
  end

  def compute_estimate(data)
    page_tokens = data.filter_map do |datum|
      length = datum.text.to_s.length
      (length / CHARS_PER_TOKEN) if length.positive?
    end

    Estimate.new(
      tokens: page_tokens.sum,
      pages: page_tokens.size,
      unfetched_pages: sources.size - page_tokens.size,
      largest_page_tokens: page_tokens.max.to_i
    )
  end
end
