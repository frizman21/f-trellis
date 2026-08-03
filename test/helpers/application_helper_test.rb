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

  test "running_version_badge links the short sha to the commit" do
    badge = running_version_badge(short: "012345", commit_url: "https://example.com/commit/0123456789")

    assert_dom_equal(
      %(<a class="text-white-50 small font-monospace text-decoration-none me-3" ) +
        %(title="Running commit — open on GitHub" href="https://example.com/commit/0123456789">012345</a>),
      badge
    )
  end

  test "running_version_badge says so when the commit is unknown" do
    badge = running_version_badge(short: nil, commit_url: nil)

    assert_includes badge, "version unknown"
    assert_not_includes badge, "<a"
  end

  test "running_version_badge treats a blank sha as unknown" do
    assert_includes running_version_badge(short: "", commit_url: nil), "version unknown"
  end
end
