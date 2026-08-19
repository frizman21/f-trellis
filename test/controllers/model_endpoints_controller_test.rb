require "test_helper"

# The screens for a model no provider refresh discovers.
class ModelEndpointsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @endpoint = ModelEndpoint.create!(name: "Acme internal", base_url: "https://acme.internal/v1",
                                      api_key_env_var: "ACME_PAT")
  end

  teardown { ENV.delete("ACME_PAT") }

  def create_endpoint(**overrides)
    post model_endpoints_path,
         params: { model_endpoint: { name: "Second", base_url: "https://second.test/v1",
                                     api_key_env_var: "SECOND_PAT" }.merge(overrides) }
  end

  # --- listing and showing ---------------------------------------------------

  test "the index lists the endpoints" do
    get model_endpoints_path

    assert_response :success
    assert_select "a[href=?]", model_endpoint_path(@endpoint)
    assert_match(/acme\.internal/, response.body)
  end

  test "the index says so when there are none" do
    @endpoint.destroy

    get model_endpoints_path

    assert_match(/No custom endpoints yet/, response.body)
  end

  # --- adding an endpoint ----------------------------------------------------

  test "adding an endpoint lands on its page" do
    assert_difference -> { ModelEndpoint.count }, 1 do
      create_endpoint
    end

    assert_redirected_to ModelEndpoint.order(:id).last
  end

  # The reasonable mistake, and it fails at request time with something far less
  # legible than a message on the form.
  test "a bare hostname is refused on the form" do
    assert_no_difference -> { ModelEndpoint.count } do
      create_endpoint(base_url: "second.test/v1")
    end

    assert_response :unprocessable_entity
    assert_match(/full http/i, response.body)
  end

  test "editing an endpoint saves the new address" do
    patch model_endpoint_path(@endpoint),
          params: { model_endpoint: { name: @endpoint.name, base_url: "https://moved.test/v2",
                                      api_key_env_var: @endpoint.api_key_env_var } }

    assert_equal "https://moved.test/v2", @endpoint.reload.base_url
  end

  # --- the token is referenced, never shown ----------------------------------

  test "the page says whether the token variable resolves, and never its value" do
    ENV["ACME_PAT"] = "pat-super-secret"

    get model_endpoint_path(@endpoint)

    assert_match(/ACME_PAT/, response.body)
    assert_match(/is set/, response.body)
    assert_no_match(/pat-super-secret/, response.body)
  end

  test "an unset token variable is called out" do
    ENV.delete("ACME_PAT")

    get model_endpoint_path(@endpoint)

    assert_match(/is not set/, response.body)
  end

  test "an endpoint naming no variable reads as unauthenticated, not as broken" do
    @endpoint.update!(api_key_env_var: "")

    get model_endpoint_path(@endpoint)

    assert_match(/unauthenticated/, response.body)
    assert_no_match(/is not set/, response.body)
  end

  # --- adding models ---------------------------------------------------------

  test "adding a model id creates a custom model joined to this endpoint" do
    assert_difference -> { Model.count }, 1 do
      post model_endpoint_models_path(@endpoint), params: { model: { model_id: "acme-large", name: "Acme Large" } }
    end

    model = Model.order(:id).last

    assert_equal "custom_endpoint", model.provider
    assert_equal @endpoint, model.model_endpoint
    assert_includes Model.selectable, model
    assert_redirected_to @endpoint
  end

  test "a model added without a name is named after its id" do
    post model_endpoint_models_path(@endpoint), params: { model: { model_id: "acme-small", name: "" } }

    assert_equal "acme-small", Model.order(:id).last.name
  end

  test "the same id twice is refused rather than duplicated" do
    @endpoint.models.create!(provider: "custom_endpoint", model_id: "acme-large", name: "Acme Large")

    assert_no_difference -> { Model.count } do
      post model_endpoint_models_path(@endpoint), params: { model: { model_id: "acme-large", name: "Again" } }
    end

    assert_response :unprocessable_entity
    assert_match(/already been taken/i, response.body)
  end

  # --- deleting --------------------------------------------------------------

  # Chats, runs, reports and skills point at the models; the models point at the
  # endpoint. Deleting it would leave rows naming a model nothing can reach.
  test "an endpoint still serving models is not deleted" do
    @endpoint.models.create!(provider: "custom_endpoint", model_id: "acme-large", name: "Acme Large")

    assert_no_difference -> { ModelEndpoint.count } do
      delete model_endpoint_path(@endpoint)
    end

    assert_match(/Disable them first/, flash[:alert])
  end

  test "an endpoint with no models is deleted" do
    assert_difference -> { ModelEndpoint.count }, -1 do
      delete model_endpoint_path(@endpoint)
    end

    assert_redirected_to model_endpoints_path
  end

  # The point of all of it: a custom model is offered beside the registered ones,
  # not on a screen of its own.
  test "a custom model is offered where a project picks its default" do
    Model.create!(provider: "anthropic", model_id: "claude-test", name: "Claude Test",
                  last_seen_at: Time.current)
    custom = @endpoint.models.create!(provider: "custom_endpoint", model_id: "acme-large",
                                      name: "Acme Large")

    get edit_project_path(projects(:apollo))

    assert_select "select[name=?] option[value=?]", "project[default_model_id]", custom.id.to_s
  end

  # --- the check -------------------------------------------------------------

  # The button reports what came back; EndpointCheck's own test covers what each
  # answer means. Stubbed at the request, so the routing, the flash and the
  # redirect are the real ones.
  test "the check reports its outcome on the endpoint's page" do
    EndpointCheck.class_eval do
      alias_method :get_without_stub, :get
      define_method(:get) do |_url|
        response = Net::HTTPOK.new("1.1", "200", "")
        response.instance_variable_set(:@body, { "data" => [ { "id" => "acme-large" } ] }.to_json)
        response.instance_variable_set(:@read, true)
        response
      end
    end

    post check_model_endpoint_path(@endpoint)

    assert_redirected_to @endpoint
    assert_match(/Reachable/, flash[:notice])
  ensure
    EndpointCheck.class_eval do
      remove_method :get
      alias_method :get, :get_without_stub
      remove_method :get_without_stub
    end
  end

  # --- read-only accounts ----------------------------------------------------

  test "a read-only account cannot add an endpoint" do
    sign_in User.create!(email: "reader-endpoints@example.com", password: "password", read_only: true)

    assert_no_difference -> { ModelEndpoint.count } do
      create_endpoint
    end

    assert_response :forbidden
  end
end
