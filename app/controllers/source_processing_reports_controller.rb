class SourceProcessingReportsController < ApplicationController
  def index
    @reports = SourceProcessingReport
                 .includes(:source, :skill_revision, :model, :chat)
                 .order(created_at: :desc)
                 .page(params[:page]).per(25)
  end

  def new
    @report = SourceProcessingReport.new
    @sources = Source.where(status: "complete").order(created_at: :desc)
    @skills  = Skill.includes(:skill_revisions, :preferred_model).order(:name)
    @models  = Model.selectable
  end

  def create
    skill = Skill.find(params.dig(:source_processing_report, :skill_id))
    revision = skill.skill_revisions.order(:sequence).last

    if revision.nil?
      redirect_to new_source_processing_report_path,
                  alert: "Skill ##{skill.id} has no revisions yet."
      return
    end

    source = Source.find_by(id: params.dig(:source_processing_report, :source_id))

    # The page asked not to be kept as a retrievable record, and turning it into
    # graph facts is exactly that. It stays readable in the app.
    if source&.is_noindex
      redirect_to new_source_processing_report_path,
                  alert: "Source ##{source.id} is marked noindex, so it is not processed into " \
                         "the knowledge graph. Its content is still readable on its page."
      return
    end

    existing = SourceProcessingReport.covering(source: source, skill_revision: revision)

    if existing
      redirect_to source_processing_reports_path,
                  notice: "Report ##{existing.id} already covers this source's current " \
                          "content for #{skill.name}; nothing queued."
      return
    end

    # An explicit pick on the form wins; otherwise the revision's own model, and
    # the skill's only for revisions written before the column existed.
    chosen_model_id = params.dig(:source_processing_report, :model_id).presence

    @report = SourceProcessingReport.new(
      source: source,
      model_id: chosen_model_id || revision.model_id || skill.preferred_model_id,
      skill_revision: revision,
      status: "new",
      facts: []
    )

    if @report.save
      ProcessReportJob.perform_later(@report)
      redirect_to source_processing_reports_path,
                  notice: "Report ##{@report.id} queued for processing."
    else
      @sources = Source.where(status: "complete").order(created_at: :desc)
      @skills  = Skill.includes(:skill_revisions, :preferred_model).order(:name)
      @models  = Model.selectable
      render :new, status: :unprocessable_entity
    end
  end
end
