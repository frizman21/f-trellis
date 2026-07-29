require "test_helper"

class SkillsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @skill = skills(:promoted_1)
  end

  test "show renders the preferred model with its provider and pricing" do
    @skill.update!(preferred_model: Model.create!(
      provider: "openai",
      model_id: "gpt-4.1-mini",
      name: "GPT-4.1 mini",
      last_seen_at: Time.current,
      pricing: { "text_tokens" => { "standard" => { "input_per_million" => 0.4, "output_per_million" => 1.6 } } }
    ))

    get skill_path(@skill)

    assert_response :success
    assert_match "Preferred model", @response.body
    assert_match "gpt-4.1-mini", @response.body
    assert_match "openai", @response.body
    assert_match "$0.4 in / $1.6 out per Mtok", @response.body
  end

  test "show renders a placeholder when the skill has no preferred model" do
    @skill.update!(preferred_model: nil)

    get skill_path(@skill)

    assert_response :success
    assert_match "Preferred model", @response.body
  end

  test "show omits pricing when the model carries none" do
    @skill.update!(preferred_model: Model.create!(
      provider: "anthropic", model_id: "unpriced", name: "Unpriced", last_seen_at: Time.current
    ))

    get skill_path(@skill)

    assert_response :success
    assert_match "unpriced", @response.body
    assert_no_match(/per Mtok/, @response.body)
  end

  test "show requires authentication" do
    sign_out users(:admin)

    get skill_path(@skill)

    assert_redirected_to new_user_session_path
  end
end
