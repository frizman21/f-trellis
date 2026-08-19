require "test_helper"

# What the Check button says. The branches are the point: a 200, a refused
# credential, an endpoint that answered with something else, and one that could
# not be reached at all each need a different sentence.
class EndpointCheckTest < ActiveSupport::TestCase
  setup do
    @endpoint = ModelEndpoint.create!(name: "Acme internal", base_url: "https://acme.internal/v1",
                                      api_key_env_var: "ACME_PAT")
  end

  teardown { ENV.delete("ACME_PAT") }

  # Stubs the request, not the classification. Aliased rather than replaced,
  # mirroring the crawl tests: the method is defined on EndpointCheck itself, so
  # define_method would leave the class without one when the stub is removed.
  #
  # `response` is a Net::HTTPResponse to return, or an exception to raise.
  def with_response(response)
    EndpointCheck.class_eval do
      alias_method :get_without_stub, :get
      define_method(:get) do |_url|
        raise response if response.is_a?(Exception)

        response
      end
    end
    yield
  ensure
    EndpointCheck.class_eval do
      remove_method :get
      alias_method :get, :get_without_stub
      remove_method :get_without_stub
    end
  end

  def http_response(klass, code, body = "")
    response = klass.new("1.1", code, "")
    response.instance_variable_set(:@body, body)
    response.instance_variable_set(:@read, true)
    response
  end

  test "a model list is reported with its count" do
    body = { "data" => [ { "id" => "acme-large" }, { "id" => "acme-small" } ] }.to_json

    with_response(http_response(Net::HTTPOK, "200", body)) do
      result = EndpointCheck.call(@endpoint)

      assert result.ok?
      assert_match(/2 models/, result.message)
    end
  end

  test "one model is not called 1 models" do
    body = { "data" => [ { "id" => "acme-large" } ] }.to_json

    with_response(http_response(Net::HTTPOK, "200", body)) do
      assert_match(/1 model\b/, EndpointCheck.call(@endpoint).message)
    end
  end

  # The address and the credential are what was being asked about, and a 200
  # settles both. What the body held is a lesser detail.
  test "a 200 that is not a model list still counts as reachable" do
    with_response(http_response(Net::HTTPOK, "200", "not json at all")) do
      result = EndpointCheck.call(@endpoint)

      assert result.ok?
      assert_match(/Reachable/, result.message)
    end
  end

  test "a refused credential names the variable and whether it is set" do
    ENV.delete("ACME_PAT")

    with_response(http_response(Net::HTTPUnauthorized, "401")) do
      result = EndpointCheck.call(@endpoint)

      assert_not result.ok?
      assert_match(/401/, result.message)
      assert_match(/ACME_PAT is not set/, result.message)
    end
  end

  test "a refused credential that is set says so too" do
    ENV["ACME_PAT"] = "pat-xyz"

    with_response(http_response(Net::HTTPForbidden, "403")) do
      assert_match(/ACME_PAT is set/, EndpointCheck.call(@endpoint).message)
    end
  end

  test "any other status is reported as answered but not with a model list" do
    with_response(http_response(Net::HTTPNotFound, "404")) do
      result = EndpointCheck.call(@endpoint)

      assert_not result.ok?
      assert_match(/404/, result.message)
    end
  end

  # Every way a request can fail is the same answer: the reason, not a stack
  # trace, and nothing about it is exceptional.
  test "an unreachable endpoint gives the reason rather than raising" do
    with_response(Errno::ECONNREFUSED.new("connect(2)")) do
      result = EndpointCheck.call(@endpoint)

      assert_not result.ok?
      assert_match(/Could not reach https:\/\/acme\.internal\/v1/, result.message)
      assert_match(/ECONNREFUSED/, result.message)
    end
  end
end
