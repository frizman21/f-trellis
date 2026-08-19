require "uri"

# Where to reach a model the provider refreshes never discovered, and which
# environment variable holds the credential for it.
#
# The token is referenced, not stored. A live PAT in a column is a live PAT in
# every backup and on the screen of anyone who can open the edit form; the
# environment already holds OPENAI_API_KEY and ANTHROPIC_API_KEY, and this row
# only needs to know which variable to read.
class ModelEndpoint < ApplicationRecord
  # Models point at the endpoint, and chats, runs, reports and skills point at
  # the models. Deleting the endpoint out from under all of that would leave
  # rows naming a model nothing can reach, so an endpoint still serving models
  # cannot be deleted — its models are disabled instead, on the model edit page.
  has_many :models, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: true
  validates :base_url, presence: true
  validate :base_url_is_an_http_address

  # Case and underscores only, because that is what an environment variable is.
  # Blank is allowed: an endpoint on a trusted network may want no auth header.
  validates :api_key_env_var, format: { with: /\A[A-Z][A-Z0-9_]*\z/,
                                        message: "looks like AN_ENV_VAR_NAME" },
                              allow_blank: true

  normalizes :base_url, with: ->(url) { url.to_s.strip.chomp("/") }
  normalizes :api_key_env_var, with: ->(name) { name.to_s.strip }

  # Read at call time rather than cached, so rotating the variable and restarting
  # is all it takes — there is no copy of it anywhere in the row.
  def api_key
    return nil if api_key_env_var.blank?

    ENV[api_key_env_var].presence
  end

  # Whether the variable this endpoint names is actually set. What the form
  # shows; the value itself is never rendered.
  def token_resolves? = api_key.present?

  # Whether a token is wanted here at all. An endpoint that names no variable is
  # not misconfigured, it is unauthenticated on purpose.
  def expects_token? = api_key_env_var.present?

  # The isolated RubyLLM config for one call to this endpoint. A context rather
  # than the global configuration: every registered OpenAI model in the
  # application still runs on the global OpenAI settings, and pointing those at
  # this endpoint would take them all with it.
  #
  # `max_retries` is the caller's, not the endpoint's: how many times a failed
  # call is worth repeating is a property of the work being done, and the two
  # callers that care disagree — a trial wants none, an extraction wants what
  # its project says. Left nil, RubyLLM's own default stands.
  def to_context(max_retries: nil)
    RubyLLM.context do |config|
      config.custom_endpoint_api_base = base_url
      config.custom_endpoint_api_key = api_key
      config.max_retries = max_retries unless max_retries.nil?
    end
  end

  private

  def base_url_is_an_http_address
    return if base_url.blank?

    uri = URI.parse(base_url)
    return if uri.is_a?(URI::HTTP) && uri.host.present?

    errors.add(:base_url, "must be a full http:// or https:// address")
  rescue URI::InvalidURIError
    errors.add(:base_url, "is not a usable address")
  end
end
