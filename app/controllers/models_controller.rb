class ModelsController < ApplicationController
  PROVIDERS = %w[anthropic openai].freeze

  def index
    @provider = params[:provider].presence
    @providers = Model.distinct.order(:provider).pluck(:provider)

    scope = Model.all
    scope = scope.where(provider: @provider) if @provider.present?
    @models = scope.order(:provider, :model_id).page(params[:page]).per(50)
  end
end
