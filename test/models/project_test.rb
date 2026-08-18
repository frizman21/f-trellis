require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  test "a project with a name is valid" do
    assert Project.new(name: "Apollo Program").valid?
  end

  test "a project without a name is invalid" do
    project = Project.new(name: nil)

    assert_not project.valid?
    assert_includes project.errors.attribute_names, :name
  end

  test "a whitespace-only name is not a name" do
    assert_not Project.new(name: "   ").valid?
  end
end
