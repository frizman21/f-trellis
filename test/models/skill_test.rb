require "test_helper"

class SkillTest < ActiveSupport::TestCase
  test "an inactive skill is valid without an applicability statement" do
    skill = Skill.new(name: "Draft", is_active: false)

    assert skill.valid?
  end

  test "an active skill requires an applicability statement" do
    skill = Skill.new(name: "Live", is_active: true)

    assert_not skill.valid?
    assert_includes skill.errors[:applicability], "can't be blank"
  end

  test "an active skill with a statement is valid" do
    skill = Skill.new(name: "Live", is_active: true, applicability: "Pages about widgets.")

    assert skill.valid?
  end

  test "activating a skill without a statement fails" do
    skill = Skill.create!(name: "Draft", is_active: false)

    assert_not skill.update(is_active: true)
    assert_includes skill.errors[:applicability], "can't be blank"
  end

  test "triageable includes active skills that state applicability and have a revision" do
    skill = Skill.create!(name: "Routable", is_active: true, applicability: "Widget pages.")
    skill.skill_revisions.create!(content: "Do it.")

    assert_includes Skill.triageable, skill
  end

  test "triageable excludes inactive skills" do
    skill = Skill.create!(name: "Inactive", is_active: false, applicability: "Widget pages.")
    skill.skill_revisions.create!(content: "Do it.")

    assert_not_includes Skill.triageable, skill
  end

  test "triageable excludes skills with no revision to run" do
    skill = Skill.create!(name: "No revision", is_active: true, applicability: "Widget pages.")

    assert_not_includes Skill.triageable, skill
  end

  test "triageable excludes skills whose statement is blank" do
    skill = Skill.create!(name: "Blank", is_active: false)
    skill.skill_revisions.create!(content: "Do it.")
    skill.update_columns(is_active: true, applicability: "")

    assert_not_includes Skill.triageable, skill
  end

  # --- url patterns -------------------------------------------------------

  test "a skill has no url patterns by default" do
    assert_equal [], Skill.create!(name: "Plain").url_patterns
  end

  test "url patterns are edited as one per line" do
    skill = Skill.new(name: "LinkedIn")
    skill.url_patterns_text = "linkedin\\.com/in/\r\n  x\\.com/status/  \n\n"

    assert_equal [ 'linkedin\.com/in/', 'x\.com/status/' ], skill.url_patterns
    assert_equal "linkedin\\.com/in/\nx\\.com/status/", skill.url_patterns_text
  end

  test "a pattern that is not a valid regular expression is rejected" do
    skill = Skill.new(name: "Broken", url_patterns: [ "linkedin(" ])

    assert_not skill.valid?
    assert_match(/invalid regular expression/, skill.errors[:url_patterns].first)
  end

  test "url_pattern_matching returns the pattern that claims the url" do
    skill = Skill.new(name: "LinkedIn", url_patterns: [ 'x\.com/status/', 'linkedin\.com/in/' ])

    assert_equal 'linkedin\.com/in/', skill.url_pattern_matching("https://www.linkedin.com/in/jane-doe/")
    assert skill.claims_url?("https://www.linkedin.com/in/jane-doe/")
  end

  test "url patterns match case insensitively and anywhere in the url" do
    skill = Skill.new(name: "LinkedIn", url_patterns: [ 'linkedin\.com/in/' ])

    assert skill.claims_url?("https://WWW.LinkedIn.COM/in/jane?trk=1")
  end

  test "a url that no pattern matches is not claimed" do
    skill = Skill.new(name: "LinkedIn", url_patterns: [ 'linkedin\.com/in/' ])

    assert_nil skill.url_pattern_matching("https://www.linkedin.com/company/acme")
    assert_nil skill.url_pattern_matching(nil)
  end

  test "a skill with no patterns claims nothing" do
    assert_not Skill.new(name: "Plain").claims_url?("https://example.com/anything")
  end

  # Validation keeps these out, but a row written around it must not raise
  # mid-routing and take the whole page down with it.
  test "a stored pattern that no longer compiles is skipped rather than raised" do
    skill = Skill.create!(name: "Broken later", url_patterns: [ 'linkedin\.com/in/' ])
    skill.update_columns(url_patterns: [ "bad(", 'linkedin\.com/in/' ])

    assert_equal 'linkedin\.com/in/', skill.reload.url_pattern_matching("https://linkedin.com/in/jane")
  end
end
