require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  def model(pricing)
    Model.new(provider: "openai", model_id: "gpt-test", name: "GPT test", pricing: pricing)
  end

  def standard(attrs)
    { "text_tokens" => { "standard" => attrs } }
  end

  test "model_pricing_label formats input and output rates" do
    label = model_pricing_label(model(standard("input_per_million" => 0.4, "output_per_million" => 1.6)))

    assert_equal "$0.4 in / $1.6 out per Mtok", label
  end

  test "model_pricing_label marks a missing side with a question mark" do
    label = model_pricing_label(model(standard("input_per_million" => 0.4)))

    assert_equal "$0.4 in / ? out per Mtok", label
  end

  test "model_pricing_label returns nil when there is no pricing at all" do
    assert_nil model_pricing_label(model(nil))
    assert_nil model_pricing_label(model({}))
    assert_nil model_pricing_label(model(standard({})))
  end

  test "model_dropdown_label appends pricing to the model id" do
    label = model_dropdown_label(model(standard("input_per_million" => 0.4, "output_per_million" => 1.6)))

    assert_equal "gpt-test — $0.4 in / $1.6 out per Mtok", label
  end

  test "model_dropdown_label falls back to the bare model id without pricing" do
    assert_equal "gpt-test", model_dropdown_label(model(nil))
  end
end
