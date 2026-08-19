# Where to reach the models no provider refresh discovers.
#
# The endpoint is the unit rather than the model: one address and one credential
# usually serve several model ids, and rotating either should be one edit rather
# than one per model.
class ModelEndpointsController < ApplicationController
  before_action :set_endpoint, only: [ :show, :edit, :update, :destroy, :check ]

  def index
    @endpoints = ModelEndpoint.includes(:models).order(:name)
  end

  def show
    @models = @endpoint.models.order(:model_id)
    @model = @endpoint.models.new
  end

  def new
    @endpoint = ModelEndpoint.new
  end

  def create
    @endpoint = ModelEndpoint.new(endpoint_params)

    if @endpoint.save
      redirect_to @endpoint, notice: "#{@endpoint.name} added. Add the model ids it serves below."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @endpoint.update(endpoint_params)
      redirect_to @endpoint, notice: "#{@endpoint.name} updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Restricted while models reference it: chats, runs, reports and skills all
  # point at those models, and deleting the address out from under them would
  # leave rows naming a model nothing can reach. Disable the models instead.
  def destroy
    if @endpoint.destroy
      redirect_to model_endpoints_path, notice: "#{@endpoint.name} removed."
    else
      redirect_to @endpoint, alert: "#{@endpoint.name} still serves " \
                                    "#{@endpoint.models.count} model(s). Disable them first, on each model's page."
    end
  end

  # The cheapest question that proves the address and the credential are both
  # right, asked when the endpoint is entered rather than discovered hours later
  # in a failed run.
  def check
    result = EndpointCheck.call(@endpoint)

    redirect_to @endpoint, (result.ok? ? :notice : :alert) => result.message
  end

  private

  def set_endpoint
    @endpoint = ModelEndpoint.find(params[:id])
  end

  # The variable's name, never a token. There is no column to put one in.
  def endpoint_params
    params.require(:model_endpoint).permit(:name, :base_url, :api_key_env_var)
  end
end
