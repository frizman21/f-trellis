# Adding a model id to an endpoint.
#
# Namespaced rather than added to ModelsController: that one is the registry
# refreshed from the providers, where every row is theirs to say and only the two
# flags are editable. This is the one place a model is entered by hand, and it
# only exists underneath the endpoint that says where to reach it.
module ModelEndpoints
  class ModelsController < ApplicationController
    # Only create. A model is never deleted — chats, runs, reports and skills
    # point at these rows — so one that is finished with is disabled on the
    # model edit page, the same as any other.
    def create
      @endpoint = ModelEndpoint.find(params[:model_endpoint_id])
      @model = @endpoint.models.new(model_params)
      # Not "openai": a custom model sharing an id with a real OpenAI model
      # would collide on the registry's unique index. See the provider in
      # config/initializers/ruby_llm.rb.
      @model.provider = "custom_endpoint"
      @model.name = @model.name.presence || @model.model_id

      if @model.save
        redirect_to @endpoint, notice: "#{@model.model_id} added. It is now offered wherever a model is picked."
      else
        @models = @endpoint.models.order(:model_id)
        render "model_endpoints/show", status: :unprocessable_entity
      end
    end

    private

    def model_params
      params.require(:model).permit(:model_id, :name)
    end
  end
end
