class SourcesController < ApplicationController
  def index
    @sources = Source.order(created_at: :desc).page(params[:page]).per(25)
  end

  def show
    @source = Source.find(params[:id])
    @links_from_count = @source.links_to.count
    @links_to_count   = @source.linked_from.count
    @learning_sets = LearningSet.order(:name)

    # What has already been run against this page. Not paginated: reports are
    # bounded by skills × revisions × re-fetches, and a page-two link would hide
    # the history the section exists to show.
    @reports = @source.source_processing_reports
                      .includes(:model, :chat, skill_revision: :skill)
                      .order(created_at: :desc)
    # Read once here rather than per row: it is what decides whether each report
    # still covers the page, and it is the same answer for all of them.
    @current_content_hash = @source.latest_datum&.content_hash
  end

  # File a page into a learning set from the page itself, so a source found
  # while browsing does not have to be re-entered by URL.
  def add_to_learning_set
    source = Source.find(params[:id])
    learning_set = LearningSet.find_by(id: params[:learning_set_id])

    if learning_set.nil?
      redirect_to source_path(source), alert: "Select a learning set first." and return
    end

    outcome = learning_set.add_source(source)
    redirect_to source_path(source), notice: outcome.message
  end

  # Sources this one's content links out to.
  def links_from
    @source = Source.find(params[:id])
    @sources = @source.links_to.order(:id).page(params[:page]).per(50)
  end

  # Sources whose content links here.
  def links_to
    @source = Source.find(params[:id])
    @sources = @source.linked_from.order(:id).page(params[:page]).per(50)
  end

  # One cheap call decides which skills are worth running on this page.
  def triage
    @source = Source.find(params[:id])
    @result = SkillTriage.call(source: @source)
    @existing = existing_reports_for(@source, @result.verdicts.map(&:skill))
  end

  # Queue the skills the operator confirmed.
  def run_triage
    source = Source.find(params[:id])
    skills = Skill.triageable.where(id: Array(params[:skill_ids]).map(&:to_i))

    if skills.empty?
      redirect_to source_path(source), alert: "No skills selected; nothing queued." and return
    end

    queued, skipped = queue_reports(source, skills)

    redirect_to source_processing_reports_path, notice: queue_notice(queued, skipped)
  end

  def new
    @source = Source.new
  end

  def create
    @source = Source.new(source_params)

    if @source.save
      @source.queue_initial_fetch
      redirect_to source_path(@source), notice: "Source ##{@source.id} created; fetch queued."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # Grab this one page's content and zip it into a new SourceDatum. Explicitly
  # requested, so it is allowed whatever the source's current status — unlike a
  # crawl, which skips pages it has already fetched.
  def fetch
    source = Source.find(params[:id])

    FetchSourceJob.perform_later(source, force: true)

    notice = if source.status == "new"
      "Fetch queued for source ##{source.id}."
    else
      "Re-fetch queued for source ##{source.id} (was #{source.status})."
    end

    redirect_to source_path(source), notice: notice
  end

  def crawl
    source = Source.find(params[:id])
    crawl_type = params[:crawl_type].to_s

    unless CrawlJob::CRAWL_TYPES.include?(crawl_type)
      redirect_to source_path(source), alert: "Invalid crawl type." and return
    end

    max_depth = params[:max_depth].to_i.clamp(0, 10)
    max_pages = (params[:max_pages].presence || CrawlJob::DEFAULT_MAX_PAGES).to_i

    CrawlJob.perform_later(source, crawl_type: crawl_type, max_depth: max_depth, max_pages: max_pages)

    redirect_to source_path(source),
                notice: "Crawl queued (type: #{crawl_type}, depth: #{max_depth}, max pages: #{max_pages})."
  end

  private

  # Reports that already cover this source's current content, keyed by skill id,
  # so triage can show what would be a no-op before anything is queued.
  def existing_reports_for(source, skills)
    skills.index_with do |skill|
      revision = skill.skill_revisions.order(:sequence).last
      revision && SourceProcessingReport.covering(source: source, skill_revision: revision)
    end.compact
  end

  def queue_reports(source, skills)
    queued = []
    skipped = []

    skills.each do |skill|
      revision = skill.skill_revisions.order(:sequence).last
      next skipped << [ skill, "no revisions" ] if revision.nil?

      if SourceProcessingReport.covering(source: source, skill_revision: revision)
        skipped << [ skill, "already covered" ]
        next
      end

      # The revision's model, not the skill's: a report runs a specific revision,
      # so it should run the model that revision pins. Revisions written before
      # the column carry none, and fall back to the skill.
      report = SourceProcessingReport.new(source: source, skill_revision: revision,
                                          model: revision.model || skill.preferred_model,
                                          status: "new", facts: [])

      if report.save
        ProcessReportJob.perform_later(report)
        queued << skill
      else
        skipped << [ skill, report.errors.full_messages.to_sentence ]
      end
    end

    [ queued, skipped ]
  end

  def queue_notice(queued, skipped)
    parts = []
    parts << "Queued #{queued.size} #{'report'.pluralize(queued.size)}: #{queued.map(&:name).to_sentence}." if queued.any?
    if skipped.any?
      details = skipped.map { |skill, reason| "#{skill.name} (#{reason})" }.to_sentence
      parts << "Skipped #{skipped.size}: #{details}."
    end
    parts.join(" ")
  end

  def source_params
    params.require(:source).permit(:url, :description)
  end
end
