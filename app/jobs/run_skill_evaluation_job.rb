# Runs one skill revision against one page through one model, keeps the reply,
# and records what the run would have contributed to the knowledge base.
#
# The model is handed the recording stand-ins, not the writing tools. That is the
# whole trick: an evaluation is a rehearsal, and a rehearsal that writes people
# and organizations into the graph would poison the thing it measures — but
# measuring *contribution* means seeing what a model proposes, which means giving
# it tools at all. The stand-ins present an identical contract and write nothing,
# so the invariant holds: an evaluation still creates no entities.
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

    recorder = ProposalRecorder.new
    chat = Chat.create!(model: result.model)
    result.update!(chat: chat)
    chat.with_instructions(instructions)
    chat.with_tools(*recording_tools(recorder))
    reply = chat.ask(source_text)

    result.record_proposals(recorder.proposals)
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

  private

  # One recorder behind all of them, so a link tool can resolve the synthetic id
  # an upsert tool handed the model a moment earlier.
  def recording_tools(recorder)
    [
      RecordingUpsertPersonTool.new(recorder),
      RecordingUpsertOrganizationTool.new(recorder),
      RecordingUpsertPartTool.new(recorder),
      RecordingUpsertScienceTool.new(recorder),
      RecordingUpsertTechnologyTool.new(recorder),
      RecordingUpsertContractTool.new(recorder),
      RecordingLinkPersonOrganizationTool.new(recorder),
      RecordingLinkPartOrganizationTool.new(recorder),
      RecordingLinkPersonPersonTool.new(recorder),
      RecordingLinkOrganizationOrganizationTool.new(recorder),
      RecordingLinkPartTechnologyTool.new(recorder),
      RecordingLinkScienceTechnologyTool.new(recorder),
      RecordingLinkPersonScienceTool.new(recorder),
      RecordingLinkContractOrganizationTool.new(recorder),
      RecordingLinkContractPersonTool.new(recorder),
      RecordingLinkContractTechnologyTool.new(recorder),
      RecordingLinkContractPartTool.new(recorder),
      RecordingLinkOrganizationTechnologyTool.new(recorder),
      RecordingCreatePersonOrganizationTypeTool.new(recorder),
      RecordingCreatePersonPersonTypeTool.new(recorder)
    ]
  end
end
