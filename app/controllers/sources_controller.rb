class SourcesController < ApplicationController
  def index
    @sources = Source.order(created_at: :desc).page(params[:page]).per(25)
  end

  def show
    @source = Source.find(params[:id])
    @links_from_count = @source.links_to.count
    @links_to_count   = @source.linked_from.count
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

  def new
    @source = Source.new
  end

  def create
    @source = Source.new(source_params)

    if @source.save
      redirect_to source_path(@source), notice: "Source ##{@source.id} created."
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

  def source_params
    params.require(:source).permit(:url, :description)
  end
end
