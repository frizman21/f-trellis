# Runs one skill revision against one page through one model and keeps the reply.
#
# Deliberately a plain chat with NO tools. ProcessReportJob hands the model the
# entity upsert tools because its job is to populate the knowledge graph; an
# evaluation is a rehearsal, and a rehearsal that writes people and organizations
# into the graph would poison the thing it is meant to measure. What is captured
# here is the response text alone.
class RunSkillEvaluationJob < ApplicationJob
  queue_as :default

  class NotRunnable < StandardError; end

  def perform(result)
    return unless result.status == "pending"

    result.update!(status: "running", started_at: Time.current)

    instructions = result.skill_revision&.content.to_s
    raise NotRunnable, "skill revision has no content" if instructions.blank?

    source_text = result.source.latest_text
    raise NotRunnable, "source has no fetched data" if source_text.blank?

    chat = Chat.create!(model: result.model)
    result.update!(chat: chat)
    chat.with_instructions(instructions)
    reply = chat.ask(source_text)

    result.update!(status: "complete", response: reply&.content.to_s,
                   error: nil, completed_at: Time.current)
  rescue StandardError => e
    Rails.logger.error("RunSkillEvaluationJob failed for result ##{result&.id}: #{e.class}: #{e.message}")
    # A failed pair is recorded and left alone: the other pairs in the run are
    # independent, and a raised job would retry the same call and bill for it.
    result&.update(status: "failed", error: "#{e.class}: #{e.message}", completed_at: Time.current)
  end
end
