require "test_helper"

class ModelsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Model.delete_all
    @now = Time.current
    @fresh   = Model.create!(provider: "anthropic", model_id: "fresh-model",   name: "Fresh",   last_seen_at: @now)
    @retired = Model.create!(provider: "anthropic", model_id: "retired-model", name: "Retired", last_seen_at: @now - 1.day)
  end

  test "index shows current models and hides retired ones" do
    get models_path

    assert_response :success
    assert_match "fresh-model", @response.body
    assert_no_match(/retired-model/, @response.body)
  end

  test "index shows retired models when show_stale is set" do
    get models_path(show_stale: 1)

    assert_response :success
    assert_match "fresh-model", @response.body
    assert_match "retired-model", @response.body
  end

  test "index filters by provider" do
    Model.create!(provider: "openai", model_id: "openai-model", name: "OpenAI", last_seen_at: @now)

    get models_path(provider: "anthropic")

    assert_response :success
    assert_match "fresh-model", @response.body
    assert_no_match(/openai-model/, @response.body)
  end

  test "refresh enqueues RefreshModelsJob and redirects" do
    assert_enqueued_with(job: RefreshModelsJob) do
      post refresh_models_path
    end

    assert_redirected_to models_path
    assert_equal "Refreshing the model registry from the configured providers. Reload in a moment.", flash[:notice]
  end

  test "refresh preserves the provider filter on redirect" do
    post refresh_models_path(provider: "anthropic")

    assert_redirected_to models_path(provider: "anthropic")
  end

  test "refresh requires authentication" do
    sign_out users(:admin)

    post refresh_models_path

    assert_redirected_to new_user_session_path
    assert_no_enqueued_jobs only: RefreshModelsJob
  end
end
