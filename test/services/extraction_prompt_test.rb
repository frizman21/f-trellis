require "test_helper"

class ExtractionPromptTest < ActiveSupport::TestCase
  setup do
    @project = projects(:apollo)
    @prompt = ExtractionPrompt.new(@project)
  end

  # --- definitions -----------------------------------------------------------

  test "names every type of the project and none of another's" do
    text = @prompt.to_s

    @project.entity_types.each { |type| assert_includes text, type.name }
    @project.relationship_types.each { |type| assert_includes text, type.name }

    assert_not_includes text, entity_types(:gemini_capsule).name
    assert_not_includes text, relationship_types(:gemini_docks).name
  end

  # This is the use the type forms promise when they say the description is the
  # context for extraction.
  test "uses each type's description as its definition" do
    assert_includes @prompt.to_s, entity_types(:rocket_engine).description
    assert_includes @prompt.to_s, relationship_types(:powers).description
  end

  test "lists each attribute with its declared value type" do
    assert_includes @prompt.to_s, "thrust_kn (float)"
    assert_includes @prompt.to_s, "chambers (int)"
    assert_includes @prompt.to_s, "engine_count (int)"
  end

  test "a disabled attribute is not asked for" do
    entity_type_attributes(:engine_thrust).update!(is_disabled: true)

    text = ExtractionPrompt.new(@project).to_s

    assert_not_includes text, "thrust_kn"
  end

  test "states which entity types a relationship type joins" do
    assert_includes @prompt.to_s, "Joins a Rocket Engine (from) to a Launch Vehicle (to)."
  end

  # Prose a model reads; prose that reads as carelessly written invites careless
  # output.
  test "the article agrees with the type name" do
    type = @project.relationship_types.create!(
      name: "Operates",
      from_entity_type: entity_types(:launch_vehicle),
      to_entity_type: entity_types(:rocket_engine)
    )
    entity_types(:launch_vehicle).update!(name: "Orbital Vehicle")

    text = ExtractionPrompt.new(@project.reload).to_s

    assert_includes text, "Joins an Orbital Vehicle (from)"
    assert type.persisted?
  end

  # --- the schema ------------------------------------------------------------

  def schema
    # Parsed rather than pattern-matched: "it looks right" is exactly what fails
    # when a model is handed the result.
    JSON.parse(@prompt.schema_json)
  end

  test "the schema is valid JSON with entities and relationships" do
    assert_equal %w[entities relationships], schema["required"]
    assert_equal "array", schema.dig("properties", "entities", "type")
    assert_equal "array", schema.dig("properties", "relationships", "type")
  end

  # Each mapping is separate, so each is asserted.
  test "the four value types map to their JSON schema types" do
    properties = schema.dig("properties", "entities", "items", "properties", "attributes", "properties")

    assert_equal({ "type" => "integer" }, properties["chambers"])
    assert_equal({ "type" => "number" }, properties["thrust_kn"])
    assert_equal({ "type" => "string" }, properties["manufacturer"])
    assert_equal({ "type" => "string", "format" => "date-time" }, properties["first_flight"])
  end

  # A source that does not state a value should produce no value rather than an
  # invented one.
  test "an entity requires a name and a type and no attribute" do
    entity = schema.dig("properties", "entities", "items")

    assert_equal %w[name type], entity["required"]
    assert_nil entity.dig("properties", "attributes", "required")
  end

  test "an entity's type is constrained to this project's types" do
    types = schema.dig("properties", "entities", "items", "properties", "type", "enum")

    assert_equal @project.entity_types.pluck(:name).sort, types.sort
    assert_not_includes types, entity_types(:gemini_capsule).name
  end

  # The model is reading a page and has no ids.
  test "relationships reference entities by name" do
    relationship = schema.dig("properties", "relationships", "items")

    assert_equal %w[type from to], relationship["required"]
    assert_equal "string", relationship.dig("properties", "from", "type")
  end

  # The schema carries the same rule the database enforces (#11).
  test "a relationship's ends are constrained to what its type declares" do
    ends = schema.dig("properties", "relationships", "items", "properties", "ends", "const")

    assert_equal({ "from" => "Rocket Engine", "to" => "Launch Vehicle" }, ends["Powers"])
  end

  # --- the instructions ------------------------------------------------------

  test "tells the model to return only JSON and not to invent values" do
    text = @prompt.instructions

    # Whitespace-tolerant: the instructions are a wrapped heredoc, and where a
    # line happens to break is not what these assertions are about.
    assert_match(/return\s+only that JSON/i, text)
    assert_match(/Do not infer, estimate, or fill a\s+gap/i, text)
    assert_match(/omit that attribute/i, text)
  end

  test "names the project it is extracting for" do
    assert_includes @prompt.instructions, @project.name
  end

  # --- nothing to extract ----------------------------------------------------

  test "a project with no types is empty rather than an empty schema" do
    Relationship.where(project: projects(:gemini)).destroy_all
    projects(:gemini).relationship_types.destroy_all
    projects(:gemini).entities.destroy_all
    projects(:gemini).entity_types.destroy_all

    assert_predicate ExtractionPrompt.new(projects(:gemini).reload), :empty?
  end
end
