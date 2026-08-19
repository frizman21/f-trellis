require "test_helper"

# One question against an endpoint's model, in the foreground, with the elapsed
# time reported. The timeout and the absence of retries are the point: a first
# call against a new endpoint must not be able to sit for twenty minutes.
class EndpointTrialTest < ActiveSupport::TestCase
  setup do
    ENV["ACME_PAT"] = "pat-xyz"
    @endpoint = ModelEndpoint.create!(name: "Acme internal", base_url: "https://acme.internal/v1",
                                      api_key_env_var: "ACME_PAT")
    @model = @endpoint.models.create!(provider: "custom_endpoint", model_id: "acme-large",
                                      name: "Acme Large")
  end

  teardown { ENV.delete("ACME_PAT") }

  Reply = Struct.new(:content, :input_tokens, :output_tokens)

  # Stubs the chat, not the classification. Captures the context the service
  # built, which is where the timeout and retry decisions live.
  class FakeChat
    class << self
      attr_accessor :reply, :raise_with, :asked
    end

    def ask(text)
      self.class.asked = text
      raise self.class.raise_with if self.class.raise_with

      self.class.reply
    end
  end

  def with_fake_chat(reply: Reply.new("ready", 18, 6), raise_with: nil)
    FakeChat.reply = reply
    FakeChat.raise_with = raise_with
    FakeChat.asked = nil
    captured = {}

    EndpointTrial.class_eval do
      alias_method :chat_without_stub, :chat
      define_method(:chat) do
        captured[:context] = send(:context)
        FakeChat.new
      end
    end

    yield captured
  ensure
    EndpointTrial.class_eval do
      remove_method :chat
      alias_method :chat, :chat_without_stub
      remove_method :chat_without_stub
    end
    FakeChat.reply = nil
    FakeChat.raise_with = nil
  end

  def trial(prompt: "Reply with one word: ready")
    EndpointTrial.call(model: @model, prompt: prompt)
  end

  # --- a reply ---------------------------------------------------------------

  test "a reply comes back with its text, its timing and its token counts" do
    with_fake_chat do
      result = trial

      assert result.ok?
      assert_equal "ready", result.reply
      assert_operator result.seconds, :>=, 0
      assert_equal 18, result.input_tokens
      assert_equal 6, result.output_tokens
    end
  end

  test "the prompt is what gets asked" do
    with_fake_chat do
      trial(prompt: "how tall is the F-1")

      assert_equal "how tall is the F-1", FakeChat.asked
    end
  end

  # --- the limits, which are the point ---------------------------------------

  test "the trial's context carries a short timeout and no retries" do
    with_fake_chat do |captured|
      trial
      config = captured[:context].config

      assert_equal EndpointTrial::TIMEOUT_SECONDS, config.request_timeout
      assert_equal 0, config.max_retries
      assert_operator config.request_timeout, :<, RubyLLM.config.request_timeout
    end
  end

  test "the trial's context still points at this endpoint" do
    with_fake_chat do |captured|
      trial
      config = captured[:context].config

      assert_equal "https://acme.internal/v1", config.custom_endpoint_api_base
      assert_equal "pat-xyz", config.custom_endpoint_api_key
    end
  end

  # The global defaults are what a real run should still get: a page of text
  # through a large model legitimately takes minutes.
  test "the global configuration is left alone" do
    with_fake_chat { trial }

    assert_equal 300, RubyLLM.config.request_timeout
    assert_equal 3, RubyLLM.config.max_retries
  end

  # --- failures are results, not exceptions ----------------------------------

  test "a timeout says which timeout, and that a real run is more patient" do
    with_fake_chat(raise_with: Faraday::TimeoutError.new("timed out")) do
      result = trial

      assert_not result.ok?
      assert_match(/within #{EndpointTrial::TIMEOUT_SECONDS}s/, result.error)
      assert_match(/may simply be slow/, result.error)
      assert_match(/#{RubyLLM.config.request_timeout}s/, result.error)
    end
  end

  test "a provider error comes back as its message" do
    with_fake_chat(raise_with: RuntimeError.new("model not loaded")) do
      result = trial

      assert_not result.ok?
      assert_match(/model not loaded/, result.error)
      assert_operator result.seconds, :>=, 0
    end
  end

  # --- nothing left behind ---------------------------------------------------

  # Kicking the tyres should not fill the Chats index with one-line
  # conversations.
  test "a trial creates no chat, either way" do
    assert_no_difference -> { Chat.count } do
      with_fake_chat { trial }
      with_fake_chat(raise_with: RuntimeError.new("nope")) { trial }
    end
  end

  # --- cost ------------------------------------------------------------------

  test "a model with no pricing reports counts but no cost" do
    with_fake_chat do
      assert_not trial.priced?
    end
  end

  test "a model with pricing reports what the call cost" do
    @model.update!(pricing: { "text_tokens" => { "standard" => { "input_per_million" => 1000.0,
                                                                 "output_per_million" => 2000.0 } } })

    with_fake_chat do
      result = trial

      assert result.priced?
      # 18 in at $1000/M plus 6 out at $2000/M.
      assert_in_delta 0.03, result.cost, 0.0001
    end
  end
end
