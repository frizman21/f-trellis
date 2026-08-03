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

  # --- revisions record the model, and are minted only on a change ---------

  def a_model(model_id)
    Model.create!(provider: "openai", model_id: model_id, name: model_id, last_seen_at: Time.current)
  end

  # Puts the skill in the shape the edit form submits from: one revision whose
  # content and model match what is currently on the skill.
  def settle(skill, content: "Do it.", model: nil)
    skill.update!(preferred_model: model)
    skill.skill_revisions.destroy_all
    skill.skill_revisions.create!(content: content, model: model)
    skill
  end

  test "changing only the preferred model adds a revision recording it" do
    old_model = a_model("gpt-old")
    new_model = a_model("gpt-new")
    settle(@skill, model: old_model)

    assert_difference "@skill.skill_revisions.count", 1 do
      patch skill_path(@skill), params: {
        skill: { name: @skill.name, preferred_model_id: new_model.id, revision_content: "Do it." }
      }
    end

    revision = @skill.reload.current_revision
    assert_equal new_model, revision.model
    assert_equal "Do it.", revision.content
  end

  test "changing only the content adds a revision carrying the current model" do
    model = a_model("gpt-steady")
    settle(@skill, model: model)

    assert_difference "@skill.skill_revisions.count", 1 do
      patch skill_path(@skill), params: {
        skill: { name: @skill.name, preferred_model_id: model.id, revision_content: "Do it differently." }
      }
    end

    revision = @skill.reload.current_revision
    assert_equal model, revision.model
    assert_equal "Do it differently.", revision.content
  end

  test "saving with neither the wording nor the model changed adds no revision" do
    model = a_model("gpt-unchanged")
    settle(@skill, model: model)

    assert_no_difference "@skill.skill_revisions.count" do
      patch skill_path(@skill), params: {
        skill: { name: @skill.name, preferred_model_id: model.id, revision_content: "Do it." }
      }
    end

    assert_match "no revision added", flash[:notice]
  end

  test "a save that adds no revision still persists the skill's own attributes" do
    model = a_model("gpt-attrs")
    settle(@skill, model: model)

    assert_no_difference "@skill.skill_revisions.count" do
      patch skill_path(@skill), params: {
        skill: {
          name: @skill.name,
          applicability: "Only widget pages.",
          url_patterns_text: 'widgets\.example\.com',
          preferred_model_id: model.id,
          revision_content: "Do it."
        }
      }
    end

    @skill.reload
    assert_equal "Only widget pages.", @skill.applicability
    assert_equal [ 'widgets\.example\.com' ], @skill.url_patterns
  end

  test "creating a skill records the model on its first revision" do
    model = a_model("gpt-first")

    post skills_path, params: {
      skill: { name: "Brand New", applicability: "Pages.", preferred_model_id: model.id,
               revision_content: "Do it." }
    }

    revision = Skill.find_by(name: "Brand New").current_revision
    assert_equal model, revision.model
    assert_equal "Do it.", revision.content
  end

  test "show renders the model of each revision" do
    settle(@skill, model: a_model("gpt-shown"))

    get skill_path(@skill)

    assert_response :success
    assert_match "gpt-shown", @response.body
  end

  test "show says so for a revision with no model recorded" do
    settle(@skill, model: nil)

    get skill_path(@skill)

    assert_response :success
    assert_match "not recorded", @response.body
  end

  test "show requires authentication" do
    sign_out users(:admin)

    get skill_path(@skill)

    assert_redirected_to new_user_session_path
  end
end
