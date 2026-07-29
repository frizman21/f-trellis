class ModelsController < ApplicationController
  def index
    @provider  = params[:provider].presence
    @show_stale = params[:show_stale].present?
    @providers = Model.distinct.order(:provider).pluck(:provider)
    @last_refreshed_at = Model.maximum(:last_seen_at)
    @stale_count = Model.where.not(id: Model.current.select(:id)).count

    scope = @show_stale ? Model.all : Model.current
    scope = scope.where(provider: @provider) if @provider.present?
    @models = scope.order(:provider, :model_id).page(params[:page]).per(50)
  end

  def refresh
    RefreshModelsJob.perform_later
    redirect_to models_path(provider: params[:provider]),
                notice: "Refreshing the model registry from the configured providers. Reload in a moment."
  end
end
