class ModelsController < ApplicationController
  # Columns a search term is matched against. Provider and family are in here
  # because "openai" and "gpt-5" are how people describe the row they are after
  # as often as they know its exact id.
  SEARCH_COLUMNS = %w[provider model_id name family].freeze

  def index
    @provider  = params[:provider].presence
    @query     = params[:q].to_s.strip.presence
    @show_stale = params[:show_stale].present?
    @providers = Model.distinct.order(:provider).pluck(:provider)
    @last_refreshed_at = Model.maximum(:last_seen_at)
    @stale_count = Model.where.not(id: Model.current.select(:id)).count
    @unusable_count = Model.current.out_of_circulation.count

    scope = @show_stale ? Model.all : Model.current
    scope = scope.where(provider: @provider) if @provider.present?
    scope = search(scope, @query) if @query
    @models = scope.order(:provider, :model_id).page(params[:page]).per(50)
  end

  def edit
    @model = Model.find(params[:id])
  end

  # Only the two flags. Everything else on the row is the provider's to say, and
  # RefreshModelsJob would overwrite a hand edit at the next refresh anyway.
  def update
    @model = Model.find(params[:id])

    if @model.update(model_params)
      redirect_to models_path(index_filters), notice: "#{@model.model_id} updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def refresh
    RefreshModelsJob.perform_later
    redirect_to models_path(index_filters),
                notice: "Refreshing the model registry from the configured providers. Reload in a moment."
  end

  private

  def model_params
    params.require(:model).permit(:is_deprecated, :is_disabled)
  end

  # Case-insensitive substring over SEARCH_COLUMNS. One term against every
  # column — the registry is a few hundred rows, so this stays a LIKE rather
  # than anything that would need an index to keep up.
  def search(scope, term)
    clause = SEARCH_COLUMNS.map { |column| "#{column} ILIKE :term" }.join(" OR ")
    scope.where(clause, term: "%#{ActiveRecord::Base.sanitize_sql_like(term)}%")
  end

  # The filters the index was showing, so editing a row and saving lands back on
  # the same list rather than on page one of everything.
  def index_filters
    { provider: params[:provider].presence, q: params[:q].presence,
      show_stale: params[:show_stale].presence, page: params[:page].presence }.compact
  end
end
