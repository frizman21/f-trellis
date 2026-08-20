# One occasion on which a project's facts were recorded against one source.
#
# Usually an attempt at running the extraction prompt: it records the reply and
# nothing more, because turning the JSON into records is separate work with its
# own questions — matching against entities that already exist, what to do with
# a type the model invented, what confidence a citation earns.
#
# Since #71 it is also what a person's own edit belongs to. Every citation names
# a run, so a fact recorded by hand needs one too; `manual` builds it. Such a
# run has no chat and no reply, and its model is the sentinel described there.
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

  # The run a person's own edit belongs to, created fresh for each submission —
  # editing the same entity twice is two sightings, not one.
  #
  # Not a nullable model_id: `manual` is absent from Model::SELECTABLE_PROVIDERS,
  # so every picker excludes the sentinel already, and Model.current excludes it
  # from the models index since nothing stamps its last_seen_at.
  def self.manual(project:, source: nil, source_id: nil)
    create!(project: project, source: source, source_id: source_id || source&.id,
            model: manual_model, status: "complete",
            started_at: Time.current, completed_at: Time.current)
  end

  def self.manual_model
    Model.find_or_create_by!(provider: "manual", model_id: "manual") do |model|
      model.name = "Entered by hand"
    end
  end

  # Nothing asked a model for this one.
  def manual? = model&.provider == "manual"

  scope :recent, -> { order(created_at: :desc) }
  scope :in_flight, -> { where(status: IN_FLIGHT) }

  # In flight for longer than a call could possibly still be open. The usual
  # cause is a worker that died — in development every server restart kills the
  # async adapter's threads — and the row then says `running` forever.
  #
  # Measured from `started_at` when there is one and `created_at` otherwise, so
  # a run that was queued and never picked up is covered too.
  scope :stalled, -> {
    in_flight.where(
      "COALESCE(extraction_runs.started_at, extraction_runs.created_at) < ?", stall_after.ago
    )
  }

  # In flight and still plausibly working. `in_flight` deliberately keeps its
  # old meaning — anything that wants "not yet finished" still wants that — and
  # only the question "may I start another?" narrows to this.
  scope :live, -> { in_flight.where.not(id: stalled.select(:id)) }

  # Derived rather than chosen. RubyLLM waits `request_timeout` per attempt and
  # makes `max_retries + 1` of them, so nothing can legitimately be open past
  # that; the grace covers queueing and the writes either side. A hardcoded
  # number would be wrong the first time anybody tuned the configuration.
  GRACE = 5.minutes

  # What a call cannot outlive: RubyLLM waits `request_timeout` per attempt and
  # makes `max_retries + 1` of them. Said out loud on the page while a run works.
  def self.gives_up_after
    (RubyLLM.config.request_timeout * (RubyLLM.config.max_retries + 1)).seconds
  end

  def self.stall_after = gives_up_after + GRACE

  def in_flight? = IN_FLIGHT.include?(status)
  def complete? = status == "complete"
  def failed? = status == "failed"

  def stalled? = in_flight? && started_or_created_at < self.class.stall_after.ago

  # Still in flight and still worth waiting for.
  def live? = in_flight? && !stalled?

  # How long this run has been going, or went on for. Seconds.
  def elapsed
    finish = completed_at || Time.current
    finish - started_or_created_at
  end

  def started_or_created_at = started_at || created_at

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
