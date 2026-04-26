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
