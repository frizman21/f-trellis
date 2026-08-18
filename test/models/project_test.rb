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

  # Both sides go with the project. Declaration order matters here: EntityType
  # restricts on its entities, so destroying types before entities would abandon
  # the destroy and leave the project standing.
  test "destroying a project destroys its ontology and its data" do
    project = projects(:apollo)

    assert project.destroy
    assert_not Project.exists?(project.id)
    assert_empty EntityType.where(project_id: project.id)
    assert_empty Entity.where(project_id: project.id)
    assert_empty EntityTypeAttribute.where(project_id: project.id)
    assert_empty EntityAttributeValue.where(project_id: project.id)
    assert_empty Relationship.where(project_id: project.id)
  end

  test "destroying a project leaves another project's two sides alone" do
    projects(:apollo).destroy

    assert EntityType.exists?(entity_types(:gemini_capsule).id)
    assert Entity.exists?(entities(:gemini_capsule).id)
  end
end
