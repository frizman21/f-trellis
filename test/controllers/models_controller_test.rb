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

  test "index searches id, name, family and provider" do
    Model.create!(provider: "openai", model_id: "gpt-5-nano", name: "GPT-5 Nano",
                  family: "gpt-5", last_seen_at: @now)

    get models_path(q: "nano")
    assert_response :success
    assert_match "gpt-5-nano", @response.body
    assert_no_match(/fresh-model/, @response.body)

    get models_path(q: "gpt-5")
    assert_match "gpt-5-nano", @response.body

    get models_path(q: "openai")
    assert_match "gpt-5-nano", @response.body
    assert_no_match(/fresh-model/, @response.body)
  end

  test "index search combines with the provider filter" do
    Model.create!(provider: "openai", model_id: "openai-fresh-model", name: "OpenAI", last_seen_at: @now)

    get models_path(q: "fresh", provider: "anthropic")

    assert_response :success
    assert_match "fresh-model", @response.body
    assert_no_match(/openai-fresh-model/, @response.body)
  end

  test "index says so when a search matches nothing" do
    get models_path(q: "no-such-model")

    assert_response :success
    assert_match(/Nothing matches/, @response.body)
  end

  test "update sets and clears both flags" do
    patch model_path(@fresh), params: { model: { is_deprecated: "1", is_disabled: "1" } }

    assert_redirected_to models_path
    @fresh.reload
    assert @fresh.is_deprecated?
    assert @fresh.is_disabled?

    patch model_path(@fresh), params: { model: { is_deprecated: "0", is_disabled: "0" } }

    @fresh.reload
    assert_not @fresh.is_deprecated?
    assert_not @fresh.is_disabled?
  end

  # Everything else on the row is the provider's to say, and the next refresh
  # would overwrite a hand edit anyway.
  test "update writes nothing but the two flags" do
    patch model_path(@fresh), params: { model: { model_id: "renamed", name: "Renamed", is_disabled: "1" } }

    @fresh.reload
    assert_equal "fresh-model", @fresh.model_id
    assert_equal "Fresh", @fresh.name
    assert @fresh.is_disabled?, "the permitted flag still went through"
  end

  test "update returns to the list it was called from" do
    patch model_path(@fresh, provider: "anthropic", q: "fresh"),
          params: { model: { is_disabled: "1" } }

    assert_redirected_to models_path(provider: "anthropic", q: "fresh")
  end

  test "edit renders the flags for one model" do
    get edit_model_path(@fresh)

    assert_response :success
    assert_match "fresh-model", @response.body
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
