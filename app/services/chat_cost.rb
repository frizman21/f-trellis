# What a chat cost, as well as it can be known.
#
# A service rather than view arithmetic: the figure is wanted on two screens
# now and on an extraction run and a project total later, and money computed
# inline in ERB is money computed differently in each place.
#
# It is an *estimate*, and the screens say so, because `input_tokens` is not
# being recorded correctly — every chat in this database reports 3 input tokens
# regardless of prompt size, including one with a 21,349-character system
# prompt. Output tokens look right and cached tokens are recorded when the
# provider reports them.
class ChatCost
  # The usual rough conversion for English prose. Only used where the recorded
  # figure is missing or implausible.
  CHARS_PER_TOKEN = 4

  # What the registry calls the discounted rate for input served from cache.
  # Both spellings are looked for because the registry is populated from two
  # sources and only one of them has been seen to use the first.
  CACHED_RATE_KEYS = %w[cache_read_input_per_million cached_input_per_million].freeze

  def initialize(chat)
    @chat = chat
    @messages = chat.messages.to_a
  end

  attr_reader :chat, :messages

  # nil rather than zero when there is no pricing to apply. Zero is a claim; a
  # dash on the screen is the absence of one.
  def total
    return nil if rates.empty?

    input_cost + cached_cost + output_cost
  end

  def input_cost = priced(billable_input_tokens, rates["input_per_million"])
  def output_cost = priced(output_tokens, rates["output_per_million"])

  # Cached tokens are a *subset* of the input, not an addition to it: the
  # provider reports how much of the prompt it served from cache. Pricing them
  # on top of the full input would bill the same tokens twice.
  def billable_input_tokens = [ input_tokens - cached_tokens, 0 ].max

  # At the discounted rate when the registry records one, which it does for the
  # models actually in use. Falling back to the full input rate overstates rather
  # than understates, which is the safer direction to be wrong in.
  def cached_cost
    priced(cached_tokens, cached_rate || rates["input_per_million"])
  end

  def cached_rate = CACHED_RATE_KEYS.filter_map { |key| rates[key] }.first
  def cached_rate_known? = cached_rate.present?

  # The larger of what was recorded and what the content implies. A correct
  # recording wins where the provider reports one; the estimate wins where the
  # field is broken. An estimate that is too low is the failure that matters —
  # it makes a run look cheaper than it was.
  def input_tokens
    [ recorded_input_tokens, estimated_input_tokens ].max
  end

  def estimated? = estimated_input_tokens > recorded_input_tokens

  def output_tokens = messages.sum { |m| m.output_tokens.to_i }
  def cached_tokens = messages.sum { |m| m.cached_tokens.to_i }

  def recorded_input_tokens = messages.sum { |m| m.input_tokens.to_i }

  # Everything sent to the model: the instructions and the question, but not the
  # reply, which is priced as output.
  def estimated_input_tokens
    sent = messages.reject { |m| m.role.to_s == "assistant" }
    (sent.sum { |m| m.content.to_s.length } / CHARS_PER_TOKEN.to_f).ceil
  end

  private

  def rates
    @rates ||= chat.model&.pricing&.dig("text_tokens", "standard") || {}
  end

  def priced(tokens, rate)
    return 0.0 if rate.blank?

    tokens / 1_000_000.0 * rate.to_f
  end
end
