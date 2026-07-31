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
end
