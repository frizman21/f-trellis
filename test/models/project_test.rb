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

  # --- extraction attempts (#62) ---------------------------------------------

  # One call, no retry. RubyLLM's own default is three retries, which is four
  # calls billed for a run that a dropped connection makes hopeless anyway.
  test "a new project attempts an extraction once" do
    assert_equal 1, Project.create!(name: "Voyager").extraction_attempts
  end

  test "attempts are translated into the retries RubyLLM counts" do
    project = Project.new(name: "Voyager", extraction_attempts: 1)

    assert_equal 0, project.extraction_max_retries

    project.extraction_attempts = 4

    assert_equal 3, project.extraction_max_retries
  end

  # Zero attempts is not "do not extract", it is a run that calls nothing and
  # fails for a reason nobody could read off the page.
  test "fewer than one attempt is not a setting" do
    project = Project.new(name: "Voyager", extraction_attempts: 0)

    assert_not project.valid?
    assert_includes project.errors.attribute_names, :extraction_attempts
  end

  test "an unbounded number of attempts is not a setting either" do
    assert_not Project.new(name: "Voyager", extraction_attempts: 11).valid?
  end

  test "a fractional attempt is not a setting" do
    assert_not Project.new(name: "Voyager", extraction_attempts: 2.5).valid?
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
