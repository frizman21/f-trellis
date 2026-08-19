# What created a chat, and how that turned out.
#
# A chat records the conversation and nothing about why it happened, so landing
# on /chats/9 leaves you with two messages, no outcome, and no way back. Three
# things reference a chat, and one of them owns any given chat.
#
# A trial from an endpoint's Try it panel creates no chat at all, and older rows
# may have lost theirs, so no owner is an ordinary answer rather than an error.
class ChatOwner
  Found = Struct.new(:label, :status, :error, :path, :stalled, keyword_init: true) do
    def stalled? = stalled
    def failed? = status == "failed"
    def complete? = status == "complete"
  end

  # Ordered by how often a chat has one. Each is asked for exactly one row.
  def self.for(chat, routes: Rails.application.routes.url_helpers)
    from_extraction_run(chat, routes) ||
      from_processing_report(chat, routes) ||
      from_evaluation_result(chat, routes)
  end

  def self.from_extraction_run(chat, routes)
    run = ExtractionRun.includes(:source).find_by(chat_id: chat.id)
    return nil if run.nil?

    Found.new(label: "Extraction run ##{run.id}",
              status: run.stalled? ? "stalled" : run.status,
              error: run.error.presence,
              path: routes.project_source_path(run.project_id, run.source_id),
              stalled: run.stalled?)
  end

  def self.from_processing_report(chat, routes)
    report = SourceProcessingReport.find_by(chat_id: chat.id)
    return nil if report.nil?

    Found.new(label: "Processing report ##{report.id}", status: report.status,
              error: report.error.presence,
              path: routes.source_path(report.source_id), stalled: false)
  end

  def self.from_evaluation_result(chat, routes)
    result = SkillEvaluationResult.find_by(chat_id: chat.id)
    return nil if result.nil?

    Found.new(label: "Evaluation result ##{result.id}", status: result.status,
              error: result.try(:error).presence,
              path: routes.skill_evaluation_result_path(result), stalled: false)
  end

  private_class_method :from_extraction_run, :from_processing_report, :from_evaluation_result
end
