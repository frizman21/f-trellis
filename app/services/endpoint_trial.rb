# Asks one of an endpoint's models a single question, in the foreground, and
# says what came back and how long it took.
#
# Foreground, unlike every other model call in this application. That is the
# feature rather than an oversight: a job would put the answer somewhere else
# and reintroduce exactly the wait this exists to remove. The short timeout
# below is what makes holding a request open safe.
#
# The elapsed time matters as much as the reply. RubyLLM defaults to a 300s
# timeout and three retries, so a first call against a new endpoint can sit for
# twenty minutes before saying anything, and the only place that surfaces is a
# run stuck on "Waiting for the model…". Knowing a 20B answers in three seconds
# and a 120B in ninety is what decides which one a project runs on.
class EndpointTrial
  # Long enough for a small model on modest hardware to finish a one-line
  # answer, short enough that a person waits rather than wonders. Stated on the
  # page, so a timeout here is not read as proof the endpoint is broken.
  TIMEOUT_SECONDS = 30

  # None. A retry would triple the wait to re-ask a question whose whole purpose
  # is to fail fast.
  MAX_RETRIES = 0

  Result = Struct.new(:ok, :reply, :seconds, :input_tokens, :output_tokens, :cost, :error,
                      keyword_init: true) do
    def ok? = ok

    # nil rather than zero when the model carries no pricing, which is the usual
    # case for a custom endpoint. Zero is a claim; a dash on the screen is the
    # absence of one.
    def priced? = !cost.nil?

    def tokens? = !input_tokens.nil? || !output_tokens.nil?
  end

  def self.call(model:, prompt:) = new(model: model, prompt: prompt).call

  def initialize(model:, prompt:)
    @model = model
    @prompt = prompt.to_s
  end

  def call
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    reply = chat.ask(@prompt)

    Result.new(ok: true, reply: reply&.content.to_s, seconds: elapsed_since(started),
               input_tokens: reply&.input_tokens, output_tokens: reply&.output_tokens,
               cost: cost_of(reply))
  rescue StandardError => e
    Result.new(ok: false, seconds: elapsed_since(started), error: message_for(e))
  end

  private

  # RubyLLM's own chat, not the acts_as_chat record: kicking the tyres should
  # not fill the Chats index with one-line conversations, and nothing is left to
  # clean up afterwards.
  def chat
    context.chat(model: @model.model_id, provider: @model.provider.to_sym,
                 assume_model_exists: true)
  end

  # The endpoint's context with the two limits overridden for this call only.
  # The global defaults are what a real run should still get — a page of text
  # through a large model legitimately takes minutes.
  def context
    endpoint = @model.model_endpoint

    RubyLLM.context do |config|
      config.custom_endpoint_api_base = endpoint.base_url
      config.custom_endpoint_api_key = endpoint.api_key
      config.request_timeout = TIMEOUT_SECONDS
      config.max_retries = MAX_RETRIES
    end
  end

  def elapsed_since(started)
    (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(1)
  end

  # A timeout is the outcome this exists to distinguish, so it says which
  # timeout was hit and that a real run would have waited far longer.
  def message_for(error)
    if error.is_a?(Faraday::TimeoutError) || error.is_a?(Net::ReadTimeout) ||
       error.is_a?(Net::OpenTimeout)
      return "No answer within #{TIMEOUT_SECONDS}s. The model may simply be slow — " \
             "a real run waits up to #{RubyLLM.config.request_timeout}s and retries."
    end

    "#{error.class}: #{error.message}"
  end

  # Custom models rarely carry pricing, so this is usually nil and the page shows
  # token counts alone.
  def cost_of(reply)
    return nil if reply.nil?

    input_rate = @model.input_price_per_million
    output_rate = @model.pricing&.dig("text_tokens", "standard", "output_per_million")&.to_f
    return nil if input_rate.to_f.zero? && output_rate.to_f.zero?

    (reply.input_tokens.to_i * input_rate.to_f + reply.output_tokens.to_i * output_rate.to_f) / 1_000_000.0
  end
end
