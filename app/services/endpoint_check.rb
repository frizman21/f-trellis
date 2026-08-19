require "net/http"

# Asks an endpoint for its model list and says what came back.
#
# The cheapest question that proves the address and the credential are both
# right: it is the same GET RubyLLM would make, it bills nothing, and it turns a
# wrong URL or an unset variable into a sentence on the endpoint's page rather
# than into a failed extraction run somebody finds hours later.
class EndpointCheck
  Result = Struct.new(:ok, :message, keyword_init: true) do
    def ok? = ok
  end

  TIMEOUT_SECONDS = 10

  def self.call(endpoint) = new(endpoint).call

  def initialize(endpoint)
    @endpoint = endpoint
  end

  def call
    response = get("#{@endpoint.base_url}/models")

    case response
    when Net::HTTPSuccess    then success_for(response)
    when Net::HTTPUnauthorized, Net::HTTPForbidden
      Result.new(ok: false, message: "#{status(response)} — the endpoint refused the credential#{credential_hint}.")
    else
      Result.new(ok: false, message: "#{status(response)} — the endpoint answered, but not with a model list.")
    end
  rescue StandardError => e
    # Every way a request can fail is the same answer here: the operator needs
    # the reason, not a stack trace, and nothing about this is exceptional.
    Result.new(ok: false, message: "Could not reach #{@endpoint.base_url}: #{e.class}: #{e.message}")
  end

  private

  def get(url)
    uri = URI.parse(url)
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{@endpoint.api_key}" if @endpoint.api_key

    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                    open_timeout: TIMEOUT_SECONDS, read_timeout: TIMEOUT_SECONDS) do |http|
      http.request(request)
    end
  end

  # A 200 that is not a model list still means the address and credential work,
  # which is what was being asked; the count is only reported when it is there.
  def success_for(response)
    models = JSON.parse(response.body.to_s)["data"]
    return Result.new(ok: true, message: "Reachable — #{pluralize_models(models.size)} offered.") if models.is_a?(Array)

    Result.new(ok: true, message: "Reachable — answered #{status(response)}, though not with a model list.")
  rescue JSON::ParserError
    Result.new(ok: true, message: "Reachable — answered #{status(response)} with a reply that was not JSON.")
  end

  def pluralize_models(count) = "#{count} #{count == 1 ? "model" : "models"}"

  def status(response) = "HTTP #{response.code}"

  def credential_hint
    return " (this endpoint names no token variable)" unless @endpoint.expects_token?
    return " (#{@endpoint.api_key_env_var} is not set in this environment)" unless @endpoint.token_resolves?

    " (#{@endpoint.api_key_env_var} is set)"
  end
end
