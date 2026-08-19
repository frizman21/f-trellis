# Runs a project's extraction prompt over one source with the project's model,
# and records the reply.
#
# A job rather than a request: fetching and reasoning over a page takes tens of
# seconds, which is longer than a request should live. The button enqueues and
# the page shows the run.
#
# Nothing here writes to the ontology. The reply is recorded and displayed;
# turning it into entities is separate work.
class ExtractionJob < ApplicationJob
  queue_as :default

  class NotRunnable < StandardError; end

  def perform(run)
    return unless run.status == "pending"

    run.update!(status: "running", started_at: Time.current)

    instructions = ExtractionPrompt.new(run.project).to_s
    raise NotRunnable, "this project's structure defines nothing to extract" if instructions.blank?

    # The stored payload, unzipped and stripped of markup — the same text every
    # other model call in this application is given.
    content = run.source.latest_text
    raise NotRunnable, "this source has no fetched content" if content.blank?

    chat = Chat.create!(model: run.model)
    run.update!(chat: chat)
    chat.with_instructions(instructions)
    reply = chat.ask(content)

    run.update!(status: "complete", response: reply&.content.to_s,
                error: nil, completed_at: Time.current)
  rescue StandardError => e
    # The provider saying no is an outcome of the run, and the page is where to
    # see it — the same choice RunSkillEvaluationJob makes. Raising would retry
    # the same call and bill for it again.
    Rails.logger.error("ExtractionJob failed for run ##{run&.id}: #{e.class}: #{e.message}")
    run&.update(status: "failed", error: "#{e.class}: #{e.message}", completed_at: Time.current)
    run&.model&.deprecate_for!(e)
  end
end
