require "test_helper"

# Where to reach a model no provider refresh discovers, and which environment
# variable holds the credential for it.
class ModelEndpointTest < ActiveSupport::TestCase
  def endpoint(**overrides)
    ModelEndpoint.new({ name: "Acme internal", base_url: "https://acme.internal/v1",
                        api_key_env_var: "ACME_PAT" }.merge(overrides))
  end

  test "a name and a base url are required" do
    assert_not endpoint(name: "").valid?
    assert_not endpoint(base_url: "").valid?
  end

  test "names are unique" do
    endpoint.save!

    assert_not endpoint.valid?
  end

  # A bare hostname is the reasonable mistake, and it fails at request time with
  # something far less legible than this.
  test "the base url must be a full http address" do
    assert_not endpoint(base_url: "acme.internal/v1").valid?
    assert_not endpoint(base_url: "ftp://acme.internal/v1").valid?
    assert_not endpoint(base_url: "https://").valid?
    assert endpoint(base_url: "http://localhost:11434/v1").valid?
  end

  test "a trailing slash is trimmed so the url joins predictably" do
    record = endpoint(base_url: "https://acme.internal/v1/  ")
    record.save!

    assert_equal "https://acme.internal/v1", record.base_url
  end

  # An endpoint on a trusted network is not misconfigured for wanting no auth
  # header; it is unauthenticated on purpose.
  test "the token variable is optional" do
    record = endpoint(api_key_env_var: "")

    assert record.valid?
    assert_not record.expects_token?
    assert_nil record.api_key
  end

  test "the token variable must look like one" do
    assert_not endpoint(api_key_env_var: "acme pat").valid?
    assert_not endpoint(api_key_env_var: "9LIVES").valid?
    assert endpoint(api_key_env_var: "ACME_PAT_2").valid?
  end

  # Read at call time, so rotating the variable needs no edit to the row — and
  # so nothing anywhere holds a copy of it.
  test "the token is read from the environment when it is asked for" do
    record = endpoint
    ENV.delete("ACME_PAT")

    assert_nil record.api_key
    assert_not record.token_resolves?

    ENV["ACME_PAT"] = "pat-xyz"

    assert_equal "pat-xyz", record.api_key
    assert record.token_resolves?
  ensure
    ENV.delete("ACME_PAT")
  end

  test "a variable that is set but empty counts as unset" do
    record = endpoint
    ENV["ACME_PAT"] = ""

    assert_not record.token_resolves?
  ensure
    ENV.delete("ACME_PAT")
  end

  # Chats, runs, reports and skills point at the models; the models point here.
  # Deleting the address out from under all of that would leave rows naming a
  # model nothing can reach.
  test "an endpoint still serving models cannot be destroyed" do
    record = endpoint
    record.save!
    record.models.create!(provider: "custom_endpoint", model_id: "acme-large", name: "Acme Large")

    assert_not record.destroy
    assert ModelEndpoint.exists?(record.id)
  end

  test "an endpoint with no models is destroyed" do
    record = endpoint
    record.save!

    assert record.destroy
  end

  # The per-call config, not the global one: every registered OpenAI model in
  # the application still runs on the global OpenAI settings.
  test "its context carries this endpoint's address and token" do
    ENV["ACME_PAT"] = "pat-xyz"
    config = endpoint.to_context.config

    assert_equal "https://acme.internal/v1", config.custom_endpoint_api_base
    assert_equal "pat-xyz", config.custom_endpoint_api_key
    # And leaves the global configuration where it was: pointing that at this
    # endpoint would take every other model in the application with it.
    assert_nil RubyLLM.config.custom_endpoint_api_base
  ensure
    ENV.delete("ACME_PAT")
  end
end
