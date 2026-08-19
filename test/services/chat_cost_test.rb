require "test_helper"

class ChatCostTest < ActiveSupport::TestCase
  # Round numbers so the expected cost can be worked out by hand rather than by
  # re-running the implementation's own arithmetic.
  def model_with(input: 10, output: 20, cached: nil)
    pricing = { "text_tokens" => { "standard" => { "input_per_million" => input,
                                                   "output_per_million" => output } } }
    pricing["text_tokens"]["standard"]["cached_input_per_million"] = cached if cached
    Model.create!(provider: "anthropic", model_id: "priced-#{SecureRandom.hex(4)}",
                  name: "Priced", last_seen_at: Time.current, pricing: pricing)
  end

  def chat_with(model:, system: "", user: "", output_tokens: 0, input_tokens: 0, cached_tokens: 0)
    chat = Chat.create!(model: model)
    chat.messages.create!(role: "system", content: system) if system.present?
    chat.messages.create!(role: "user", content: user) if user.present?
    chat.messages.create!(role: "assistant", content: "reply",
                          output_tokens: output_tokens, input_tokens: input_tokens,
                          cached_tokens: cached_tokens)
    chat
  end

  test "cost is input times its rate plus output times its rate" do
    # 4000 characters sent -> 1000 estimated input tokens at $10/Mtok = $0.01
    # 2000 output tokens at $20/Mtok = $0.04
    chat = chat_with(model: model_with, system: "a" * 4000, output_tokens: 2000)

    cost = ChatCost.new(chat)

    assert_equal 1000, cost.input_tokens
    assert_in_delta 0.01, cost.input_cost
    assert_in_delta 0.04, cost.output_cost
    assert_in_delta 0.05, cost.total
  end

  # Cached tokens are a subset of the input, not an addition: pricing them on top
  # of the full input bills the same tokens twice.
  test "cached tokens come out of the input rather than adding to it" do
    # 1000 estimated input tokens, 400 of them served from cache:
    # 600 at $10/Mtok = $0.006, 400 at $1/Mtok = $0.0004, output 0.
    chat = chat_with(model: model_with(input: 10, cached: 1), system: "a" * 4000,
                     cached_tokens: 400)

    cost = ChatCost.new(chat)

    assert_equal 1000, cost.input_tokens
    assert_equal 600, cost.billable_input_tokens
    assert_in_delta 0.006, cost.input_cost
    assert_in_delta 0.0004, cost.cached_cost
    assert_in_delta 0.0064, cost.total
  end

  # More cached than estimated would otherwise make the input side negative.
  test "billable input never goes below zero" do
    chat = chat_with(model: model_with, system: "a" * 40, cached_tokens: 5_000)

    assert_equal 0, ChatCost.new(chat).billable_input_tokens
  end

  # The actual condition in this database: every chat reports 3 input tokens.
  test "input is estimated when the recorded count is implausibly small" do
    chat = chat_with(model: model_with, system: "a" * 4000, input_tokens: 3)

    cost = ChatCost.new(chat)

    assert_predicate cost, :estimated?
    assert_equal 1000, cost.input_tokens
    assert_equal 3, cost.recorded_input_tokens
  end

  # A correct recording is not thrown away.
  test "the recorded count is used when it is the larger" do
    chat = chat_with(model: model_with, system: "a" * 400, input_tokens: 9_000)

    cost = ChatCost.new(chat)

    assert_not_predicate cost, :estimated?
    assert_equal 9_000, cost.input_tokens
  end

  # The reply is priced as output, so it must not also be counted as input.
  test "the assistant's reply is not counted as input" do
    chat = Chat.create!(model: model_with)
    chat.messages.create!(role: "assistant", content: "z" * 8000, output_tokens: 10)

    assert_equal 0, ChatCost.new(chat).estimated_input_tokens
  end

  # Understating the cached portion would mislead in the direction that matters.
  # Overstating is the safer direction to be wrong in.
  test "cached tokens fall back to the input rate when no cached rate is recorded" do
    chat = chat_with(model: model_with(input: 10), cached_tokens: 1_000_000)

    cost = ChatCost.new(chat)

    assert_not_predicate cost, :cached_rate_known?
    assert_in_delta 10.0, cost.cached_cost
  end

  test "cached tokens are priced at the cached rate when one is recorded" do
    chat = chat_with(model: model_with(input: 10, cached: 1), cached_tokens: 1_000_000)

    cost = ChatCost.new(chat)

    assert_predicate cost, :cached_rate_known?
    assert_in_delta 1.0, cost.cached_cost
  end

  # The registry is populated from two sources and spells this differently.
  test "the registry's own spelling of the cached rate is understood" do
    model = Model.create!(provider: "openai", model_id: "cache-read", name: "C",
                          last_seen_at: Time.current,
                          pricing: { "text_tokens" => { "standard" => {
                            "input_per_million" => 10, "output_per_million" => 20,
                            "cache_read_input_per_million" => 1 } } })
    chat = chat_with(model: model, cached_tokens: 1_000_000)

    assert_predicate ChatCost.new(chat), :cached_rate_known?
    assert_in_delta 1.0, ChatCost.new(chat).cached_cost
  end

  # Zero is a claim; nil lets the screen show a dash instead.
  test "a model with no pricing yields no total" do
    unpriced = Model.create!(provider: "anthropic", model_id: "unpriced", name: "U",
                             last_seen_at: Time.current)

    assert_nil ChatCost.new(chat_with(model: unpriced, output_tokens: 500)).total
  end

  # A chat always resolves to a model — acts_as_chat assigns the configured
  # default — so the reachable case is a model whose pricing is not recorded.
  test "a chat whose model has no pricing yields no total" do
    unpriced = Model.create!(provider: "anthropic", model_id: "no-prices", name: "N",
                             last_seen_at: Time.current, pricing: {})

    assert_nil ChatCost.new(chat_with(model: unpriced, output_tokens: 10)).total
  end

  test "a chat with no messages costs nothing rather than raising" do
    chat = Chat.create!(model: model_with)

    assert_in_delta 0.0, ChatCost.new(chat).total
  end
end
