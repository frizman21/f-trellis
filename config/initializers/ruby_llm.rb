# A model served by something other than the providers RubyLLM discovers — a
# self-hosted model, an inference vendor behind a corporate gateway, a
# colleague's endpoint. OpenAI-compatible is the wire protocol every one of them
# speaks, so this is that provider with the address and the credential taken from
# whichever ModelEndpoint the call is for.
#
# Its own provider rather than the built-in `openai` one with the base URL
# overridden. Models are unique on (provider, model_id): a custom model sharing
# an id with a real OpenAI model would collide, and the models index would file
# it under "openai", which is not where anyone would look for it.
#
# Defined here rather than under app/ or lib/: registration happens once at boot
# and must not be reloaded, and this is where the rest of the RubyLLM wiring is.
class CustomEndpointProvider < RubyLLM::Providers::OpenAI
  # Both come from the per-call config a ModelEndpoint builds, never from the
  # global one — the global OpenAI settings are still what every registered
  # OpenAI model runs on, and must not move.
  def api_base = @config.custom_endpoint_api_base

  def headers
    return {} if @config.custom_endpoint_api_key.blank?

    { "Authorization" => "Bearer #{@config.custom_endpoint_api_key}" }
  end

  class << self
    def configuration_options = %i[custom_endpoint_api_base custom_endpoint_api_key]

    # The key is not required: an endpoint on a trusted network may want no
    # auth header at all.
    def configuration_requirements = %i[custom_endpoint_api_base]

    def capabilities = RubyLLM::Providers::OpenAI::Capabilities

    # Not local: `local?` providers are exempted from cost accounting, and an
    # endpoint reached over the network may well be billing for the call.
    def local? = false
  end
end

# Before configure, which is what declares the two options above on the
# configuration class.
RubyLLM::Provider.register(:custom_endpoint, CustomEndpointProvider)

RubyLLM.configure do |config|
  config.openai_api_key    = ENV.fetch("OPENAI_API_KEY",    Rails.application.credentials.dig(:openai_api_key))
  config.anthropic_api_key = ENV.fetch("ANTHROPIC_API_KEY", Rails.application.credentials.dig(:anthropic_api_key))
  # config.default_model = "gpt-5-nano"

  # Use the new association-based acts_as API (recommended)
  config.use_new_acts_as = true
end
