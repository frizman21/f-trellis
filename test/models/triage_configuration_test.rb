require "test_helper"

class TriageConfigurationTest < ActiveSupport::TestCase
  # One shared timestamp: Model.current keeps only the rows from the most
  # recent refresh, so models stamped microseconds apart would leave the
  # earlier ones out of `selectable` entirely.
  setup { @refreshed_at = Time.current }

  def make_model(provider, model_id)
    Model.create!(provider: provider, model_id: model_id, name: model_id, last_seen_at: @refreshed_at)
  end

  test "current reads without writing" do
    assert_no_difference "TriageConfiguration.count" do
      2.times { TriageConfiguration.current }
    end

    assert_not TriageConfiguration.current.persisted?
  end

  test "current returns the saved row once one exists" do
    saved = TriageConfiguration.create!(instructions: "Route only parts pages.")

    assert_equal saved, TriageConfiguration.current
    assert_equal 1, TriageConfiguration.count,
      "there is one triage step, so there is one configuration"
  end

  test "current keeps answering with the same row if a second one exists" do
    first = TriageConfiguration.create!
    TriageConfiguration.create!

    assert_equal first.id, TriageConfiguration.current.id
  end

  test "blank instructions fall back to the default text" do
    config = TriageConfiguration.new(instructions: "   ")

    assert_equal TriageConfiguration::DEFAULT_INSTRUCTIONS, config.effective_instructions
    assert_not config.instructions_configured?
  end

  test "set instructions win over the default" do
    config = TriageConfiguration.new(instructions: "Only route pages that name a part.")

    assert_equal "Only route pages that name a part.", config.effective_instructions
    assert config.instructions_configured?
  end

  test "clearing instructions stores null rather than an empty string" do
    config = TriageConfiguration.create!(instructions: "something")
    config.update!(instructions: "  ")

    assert_nil config.reload.instructions
    assert_equal TriageConfiguration::DEFAULT_INSTRUCTIONS, config.effective_instructions
  end

  test "no model falls back to the first selectable model" do
    make_model("openai", "gpt-zzz")
    first = make_model("anthropic", "claude-aaa")

    assert_equal first, TriageConfiguration.new.effective_model
    assert_not TriageConfiguration.new.model_configured?
  end

  test "a pinned model wins over the fallback" do
    make_model("anthropic", "claude-aaa")
    pinned = make_model("openai", "gpt-zzz")

    config = TriageConfiguration.new(model: pinned)

    assert_equal pinned, config.effective_model
    assert config.model_configured?
  end

  test "effective model is nil when the registry is empty" do
    Model.delete_all

    assert_nil TriageConfiguration.new.effective_model
  end
end
