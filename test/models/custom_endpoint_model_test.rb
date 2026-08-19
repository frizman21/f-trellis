require "test_helper"

# A model served from an address somebody entered rather than from a provider's
# own registry, and how it reaches that address.
class CustomEndpointModelTest < ActiveSupport::TestCase
  setup do
    ENV["ACME_PAT"] = "pat-xyz"
    @endpoint = ModelEndpoint.create!(name: "Acme internal", base_url: "https://acme.internal/v1",
                                      api_key_env_var: "ACME_PAT")
    @custom = @endpoint.models.create!(provider: "custom_endpoint", model_id: "acme-large",
                                       name: "Acme Large")
  end

  teardown { ENV.delete("ACME_PAT") }

  def registered_model(seen_at: Time.current)
    Model.create!(provider: "anthropic", model_id: "claude-test", name: "Claude Test",
                  last_seen_at: seen_at)
  end

  def provider_for(chat) = chat.to_llm.instance_variable_get(:@provider)

  # --- reaching the endpoint -------------------------------------------------

  test "a chat for a custom model goes to the endpoint's address with its token" do
    provider = provider_for(Chat.for_model(@custom))

    assert_kind_of CustomEndpointProvider, provider
    assert_equal "https://acme.internal/v1", provider.api_base
    assert_equal({ "Authorization" => "Bearer pat-xyz" }, provider.headers)
  end

  # A custom model id is in no provider's registry, so without this the chat
  # raises rather than reaching the endpoint that does serve it.
  test "a custom model is allowed to be one RubyLLM has never heard of" do
    assert Chat.for_model(@custom).assume_model_exists
  end

  test "an endpoint naming no token sends no authorization header" do
    @endpoint.update!(api_key_env_var: "")

    assert_empty provider_for(Chat.for_model(@custom)).headers
  end

  # The global OpenAI and Anthropic configuration is what every registered model
  # still runs on, and it must not move.
  #
  # Deliberately stops short of building the provider: instantiating Anthropic's
  # requires a configured anthropic_api_key, which CI does not have and should
  # not need. The two assertions here are the ones that decide it — a chat with
  # no context and no assume_model_exists cannot reach a custom endpoint, and
  # the positive routing case is covered above.
  test "a registered model is unchanged and carries no context" do
    model = registered_model
    chat = Chat.for_model(model)

    assert_nil chat.context
    assert_not chat.assume_model_exists
    assert_equal "anthropic", chat.model.provider
  end

  # --- how many times a call may be sent (#62) -------------------------------

  def retries_in(chat) = chat.context.config.max_retries

  test "a retry limit reaches a custom model's context without moving the address" do
    chat = Chat.for_model(@custom, max_retries: 0)

    assert_equal 0, retries_in(chat)
    assert_equal "https://acme.internal/v1", provider_for(chat).api_base
    assert_equal({ "Authorization" => "Bearer pat-xyz" }, provider_for(chat).headers)
  end

  # The endpoint is not what decides this — a dropped connection is as wasteful
  # to retry against a registered provider as against a self-hosted one — so the
  # override has to reach a model that has no endpoint at all.
  test "a retry limit reaches a registered model too" do
    chat = Chat.for_model(registered_model, max_retries: 0)

    assert_equal 0, retries_in(chat)
    assert_not chat.assume_model_exists
  end

  test "asking for no limit leaves RubyLLM's own default standing" do
    chat = Chat.for_model(@custom)

    assert_equal RubyLLM.config.max_retries, retries_in(chat)
  end

  # --- staying in the pickers ------------------------------------------------

  # Model.current keeps the rows stamped by the most recent refresh. A custom
  # model is never stamped, because no provider was asked about it, so without
  # the exemption it would drop out of every dropdown the first time the
  # registry was refreshed.
  test "a custom model survives a refresh that stamps every other row" do
    registered_model(seen_at: 1.minute.from_now)

    assert_includes Model.current, @custom
    assert_includes Model.selectable, @custom
  end

  test "a disabled custom model is out of circulation like any other" do
    @custom.update!(is_disabled: true)

    assert_not_includes Model.selectable, @custom
  end

  # --- one id per provider ---------------------------------------------------

  test "the same id cannot be added to the registry twice" do
    duplicate = @endpoint.models.new(provider: "custom_endpoint", model_id: "acme-large",
                                     name: "Acme Large again")

    assert_not duplicate.valid?
  end

  # Its own provider is what makes this safe: an endpoint serving a model called
  # gpt-4o does not collide with the real one.
  test "a custom model may share an id with a registered one" do
    Model.create!(provider: "openai", model_id: "gpt-4o", name: "GPT-4o", last_seen_at: Time.current)

    assert @endpoint.models.create!(provider: "custom_endpoint", model_id: "gpt-4o",
                                    name: "Acme's gpt-4o").persisted?
  end
end
