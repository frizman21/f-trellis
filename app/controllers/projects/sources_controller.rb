# The sources a project cares about.
#
# Namespaced rather than added to SourcesController: that one is the crawler's
# own screen over every page the system knows, and this one is a project's list.
# Folding them together would mean one controller answering to two questions.
module Projects
  class SourcesController < ApplicationController
    before_action :set_project

    def index
      @sources = @project.sources
                         .includes(:domain)
                         .order(created_at: :desc)
                         .page(params[:page]).per(25)
    end

    # Found through the project, so a source another project holds is a 404 here
    # rather than a page that quietly leaves the project you were in.
    def show
      @source = @project.sources.includes(:domain).find(params[:id])
      @latest = @source.source_data.order(:created_at).last
      @other_projects = @source.projects.where.not(id: @project.id).order(:name)
      # Scoped to this project: another project reading the same page has its own
      # runs, with its own structure behind them.
      @runs = @project.extraction_runs.where(source: @source).includes(:model).recent.limit(10)
      @readiness = ExtractionReadiness.new(@project, @source)
    end

    # Enqueues a run of the project's extraction prompt over this page. The
    # reasons it might not be runnable are checked here so the button can explain
    # itself rather than being enabled and failing.
    def extract
      @source = @project.sources.find(params[:id])
      reason = ExtractionReadiness.new(@project, @source).reason

      if reason
        return redirect_to project_source_path(@project, @source), alert: reason
      end

      run = ExtractionRun.create!(project: @project, source: @source,
                                  model: @project.default_model)
      ExtractionJob.perform_later(run)

      redirect_to project_source_path(@project, @source),
                  notice: "Extraction queued with #{@project.default_model.model_id}."
    end

    def new
      @source = Source.new
    end

    def create
      # for_url normalizes, finds or creates, and queues the fetch on creation
      # only. A page already known to the crawler is attached rather than
      # duplicated: a second row for one URL would split its fetched content and
      # its processing history in half.
      @source = Source.for_url(params.dig(:source, :url))

      if @source.nil?
        @source = Source.new(source_params)
        @source.errors.add(:url, "is not a usable web address")
        return render :new, status: :unprocessable_entity
      end

      apply_description
      join = ProjectSource.find_or_initialize_by(project: @project, source: @source)
      already_joined = join.persisted?
      join.save!

      redirect_to project_sources_path(@project), notice: notice_for(join, already_joined)
    end

    # Removes the join, not the page. The source is a page on the internet:
    # another project may be using it, and its fetched content and processing
    # history outlive any one project's interest in it.
    def destroy
      join = @project.project_sources.find_by!(source_id: params[:id])
      join.destroy

      redirect_to project_sources_path(@project), notice: "Source removed from this project."
    end

    private

    def set_project
      @project = Project.find(params[:project_id])
    end

    # A description typed here is worth keeping, but not worth overwriting one
    # the crawler or another project already recorded.
    def apply_description
      description = params.dig(:source, :description)
      return if description.blank? || @source.description.present?

      @source.update!(description: description)
    end

    # Which of the three things happened is worth saying: attaching a page the
    # crawler already had should not be indistinguishable from adding a new one.
    def notice_for(join, already_joined)
      return "That source is already on this project." if already_joined
      return "Source added to this project; fetch queued." if join.source.created_at > 1.minute.ago

      "That page was already known; it is now on this project too."
    end

    def source_params
      params.require(:source).permit(:url, :description)
    end
  end
end
