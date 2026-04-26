require "zip"
require "stringio"

class ProcessReportJob < ApplicationJob
  queue_as :default

  class ReportNotProcessable < StandardError; end

  def perform(report)
    return unless report.status == "new"

    report.update!(status: "processing")

    skill_content = report.skill_revision&.content.to_s
    raise ReportNotProcessable, "skill revision has no content" if skill_content.blank?

    source_text = unzip_source(report.source)
    raise ReportNotProcessable, "source has no fetched data" if source_text.blank?

    chat = Chat.create!(model: report.model)
    report.update!(chat: chat)
    chat.with_instructions(skill_content)
    chat.with_tools(
      UpsertPersonTool.new(report),
      UpsertOrganizationTool.new(report),
      LinkPersonOrganizationTool.new(report),
      LinkOrganizationOrganizationTool.new(report)
    )
    chat.ask(source_text)

    report.update!(status: "complete")
  rescue StandardError => e
    report.update!(status: "failed") if report.persisted?
    Rails.logger.error("ProcessReportJob failed for report ##{report.id}: #{e.class}: #{e.message}")
    raise
  end

  private

  def unzip_source(source)
    datum = source&.source_data&.order(:created_at)&.last
    return nil unless datum&.data.present?

    Zip::InputStream.open(StringIO.new(datum.data)) do |io|
      while (entry = io.get_next_entry)
        return io.read.force_encoding("UTF-8")
      end
    end
    nil
  end
end
