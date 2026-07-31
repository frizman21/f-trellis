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
end
