# Runs one skill revision against one page through one model and keeps the reply.
#
# It used to hand the model recording stand-ins for the entity-writing tools, so
# an evaluation could measure what a run *would* have contributed to the
# knowledge base without writing to it. That knowledge base is gone (#4), so
# there is nothing to propose and no tools to stand in for: an evaluation is now
# the revision, the page, the model, and the text that comes back.
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

    # Recorded empty rather than skipped: SkillEvaluationResult and the
    # comparison screens still speak in proposals, and an empty set is the
    # truthful answer now that no tool can propose anything.
    result.record_proposals([])
    result.update!(status: "complete", response: reply&.content.to_s,
                   error: nil, completed_at: Time.current)
  rescue StandardError => e
    Rails.logger.error("RunSkillEvaluationJob failed for result ##{result&.id}: #{e.class}: #{e.message}")
    # A failed pair is recorded and left alone: the other pairs in the run are
    # independent, and a raised job would retry the same call and bill for it.
    result&.update(status: "failed", error: "#{e.class}: #{e.message}", completed_at: Time.current)
    # But if the provider said the model itself is finished, take it out of
    # circulation now — the rest of this run is one job per page, all of them
    # about to make the same doomed call.
    result&.model&.deprecate_for!(e)
  end
end
