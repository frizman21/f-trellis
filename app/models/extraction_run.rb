# One attempt at running a project's extraction prompt over one source.
#
# It records the reply and nothing more: no entity, relationship, value or
# citation is created from it. Turning the JSON into records is separate work
# with its own questions — matching against entities that already exist, what to
# do with a type the model invented, what confidence a citation earns.
class ExtractionRun < ApplicationRecord
  STATUSES = %w[pending running complete failed].freeze
  # A run is in flight while it is one of these; the button stays disabled so a
  # double click is not two API calls.
  IN_FLIGHT = %w[pending running].freeze

  belongs_to :project
  belongs_to :source
  belongs_to :model
  belongs_to :chat, optional: true

  validates :status, inclusion: { in: STATUSES }

  scope :recent, -> { order(created_at: :desc) }
  scope :in_flight, -> { where(status: IN_FLIGHT) }

  def in_flight? = IN_FLIGHT.include?(status)
  def complete? = status == "complete"
  def failed? = status == "failed"

  # The reply parsed, or nil when the model did not return JSON. Models wrap
  # answers in prose and in markdown fences often enough that "it did not parse"
  # is an ordinary outcome to display, not an error to raise.
  def parsed
    return nil if response.blank?

    JSON.parse(unfenced_response)
  rescue JSON::ParserError
    nil
  end

  def parsed? = !parsed.nil?

  def pretty_response
    parsed ? JSON.pretty_generate(parsed) : response
  end

  private

  # A ```json fence is the single most common way a reply that is otherwise
  # perfect fails to parse, so it is stripped before giving up on it.
  def unfenced_response
    response.to_s.strip.sub(/\A```(?:json)?\s*/m, "").sub(/```\z/m, "")
  end
end
