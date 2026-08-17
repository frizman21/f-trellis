class DomainsController < ApplicationController
  def index
    @query = params[:q].to_s.strip
    scope = Domain.left_joins(:sources)
                  .select("domains.*, COUNT(sources.id) AS sources_count")
                  .group("domains.id")
                  .order(:host)

    scope = scope.where("domains.host ILIKE ?", "%#{@query}%") if @query.present?

    @domains = scope.page(params[:page]).per(25)
  end

  def show
    @domain = Domain.find(params[:id])
    @records = @domain.crawl_records.recent.page(params[:page]).per(25)

    # Counted in the database rather than over the loaded page — a
    # well-crawled site has thousands of records and only 25 are on screen.
    counts = @domain.crawl_records.group(:outcome).count
    @crawled_count = counts.values.sum
    @failed_count  = counts.except("ok", "skipped").values.sum

    # The log holds a bare URL string, so most but not all of these still have
    # a source. Resolved in one query rather than per row.
    @sources_by_url = Source.where(url: @records.map(&:url)).index_by(&:url)
  end

  def edit
    @domain = Domain.find(params[:id])
  end

  def update
    @domain = Domain.find(params[:id])

    if @domain.update(domain_params)
      redirect_to domains_path, notice: "Domain \"#{@domain.host}\" updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def domain_params
    params.require(:domain).permit(:min_crawl_delay_seconds)
  end
end
