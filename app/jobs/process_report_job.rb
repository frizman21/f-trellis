class ProcessReportJob < ApplicationJob
  queue_as :default

  class ReportNotProcessable < StandardError; end

  def perform(report)
    return unless report.status == "new"

    report.update!(status: "processing")

    skill_content = report.skill_revision&.content.to_s
    raise ReportNotProcessable, "skill revision has no content" if skill_content.blank?

    source_text = source_text_for(report.source)
    raise ReportNotProcessable, "source has no fetched data" if source_text.blank?

    chat = Chat.create!(model: report.model)
    report.update!(chat: chat)
    chat.with_instructions(skill_content)
    chat.with_tools(
      UpsertPersonTool.new(report),
      UpsertOrganizationTool.new(report),
      UpsertPartTool.new(report),
      LinkPersonOrganizationTool.new(report),
      LinkPartOrganizationTool.new(report),
      LinkPersonPersonTool.new(report),
      LinkOrganizationOrganizationTool.new(report),
      CreatePersonOrganizationTypeTool.new(report),
      CreatePersonPersonTypeTool.new(report)
    )
    chat.ask(source_text)

    report.update!(status: "complete", error: nil)
  rescue StandardError => e
    # The message goes on the record, not only into the log: reports have no show
    # page, so the index is the only place anyone can ask why a run failed.
    report.update!(status: "failed", error: "#{e.class}: #{e.message}") if report.persisted?
    Rails.logger.error("ProcessReportJob failed for report ##{report.id}: #{e.class}: #{e.message}")
    raise
  end

  private

  # The model gets the page's text, not its markup — see ContentExtractor for
  # why. Uses the most recent payload, so a re-fetch supersedes earlier copies.
  def source_text_for(source)
    source&.source_data&.order(:created_at)&.last&.text
  end
end
