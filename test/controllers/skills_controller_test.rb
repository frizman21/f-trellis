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

  test "show renders the applicability statement" do
    @skill.update!(applicability: "Exhibitor lists and member directories.")

    get skill_path(@skill)

    assert_response :success
    assert_match "Applicability", @response.body
    assert_match "Exhibitor lists and member directories.", @response.body
  end

  test "show says so when applicability is not stated" do
    @skill.update!(applicability: nil)

    get skill_path(@skill)

    assert_response :success
    assert_match(/triage cannot route this skill/, @response.body)
  end

  test "the new form offers an applicability field" do
    get new_skill_path

    assert_response :success
    assert_select "textarea[name=?]", "skill[applicability]"
  end

  test "the edit form offers an applicability field prefilled" do
    @skill.update!(applicability: "Widget pages only.")

    get edit_skill_path(@skill)

    assert_response :success
    assert_select "textarea[name=?]", "skill[applicability]", text: /Widget pages only./
  end

  test "create persists the applicability statement" do
    assert_difference "Skill.count", 1 do
      post skills_path, params: {
        skill: { name: "Routable", applicability: "Directory pages.", revision_content: "Do it." }
      }
    end

    assert_equal "Directory pages.", Skill.find_by(name: "Routable").applicability
  end

  test "update changes applicability" do
    patch skill_path(@skill), params: {
      skill: { name: @skill.name, applicability: "Changed statement.", revision_content: "Do it." }
    }

    assert_equal "Changed statement.", @skill.reload.applicability
  end

  test "activating a skill without applicability is rejected" do
    @skill.update_columns(applicability: nil, is_active: false)

    patch skill_path(@skill), params: {
      skill: { name: @skill.name, is_active: "1", applicability: "", revision_content: "Do it." }
    }

    assert_response :unprocessable_entity
    assert_not @skill.reload.is_active?
  end

  test "the skills index shows an applicability column" do
    @skill.update!(applicability: "Directory pages and exhibitor lists.")

    get skills_path

    assert_response :success
    assert_select "th", text: "Applicability"
    assert_match "Directory pages and exhibitor lists.", @response.body
  end

  # --- url patterns -------------------------------------------------------

  test "the new form offers a url patterns field" do
    get new_skill_path

    assert_response :success
    assert_select "textarea[name=?]", "skill[url_patterns_text]"
  end

  test "the edit form prefills url patterns one per line" do
    @skill.update!(url_patterns: [ 'linkedin\.com/in/', 'x\.com/status/' ])

    get edit_skill_path(@skill)

    assert_response :success
    assert_select "textarea[name=?]", "skill[url_patterns_text]",
                  text: %r{linkedin\\\.com/in/\nx\\\.com/status/}
  end

  test "create splits the submitted lines into patterns" do
    post skills_path, params: {
      skill: {
        name: "LinkedIn-Person",
        applicability: "LinkedIn profiles.",
        url_patterns_text: "linkedin\\.com/in/\r\n\r\n  x\\.com/status/  ",
        revision_content: "Do it."
      }
    }

    assert_equal [ 'linkedin\.com/in/', 'x\.com/status/' ],
                 Skill.find_by(name: "LinkedIn-Person").url_patterns
  end

  test "update clears url patterns when the field is emptied" do
    @skill.update!(url_patterns: [ 'linkedin\.com/in/' ])

    patch skill_path(@skill), params: {
      skill: { name: @skill.name, url_patterns_text: "", revision_content: "Do it." }
    }

    assert_equal [], @skill.reload.url_patterns
  end

  test "an invalid regular expression is rejected rather than stored" do
    patch skill_path(@skill), params: {
      skill: { name: @skill.name, url_patterns_text: "linkedin(", revision_content: "Do it." }
    }

    assert_response :unprocessable_entity
    assert_equal [], @skill.reload.url_patterns
    assert_match(/invalid regular expression/, @response.body)
  end

  test "show lists the url patterns" do
    @skill.update!(url_patterns: [ 'linkedin\.com/in/' ])

    get skill_path(@skill)

    assert_response :success
    assert_select "code", text: 'linkedin\.com/in/'
  end

  test "the skills index shows a url patterns column" do
    @skill.update!(url_patterns: [ 'linkedin\.com/in/' ])

    get skills_path

    assert_response :success
    assert_select "th", text: "URL patterns"
    assert_select "td code", text: 'linkedin\.com/in/'
  end

  test "show requires authentication" do
    sign_out users(:admin)

    get skill_path(@skill)

    assert_redirected_to new_user_session_path
  end
end
