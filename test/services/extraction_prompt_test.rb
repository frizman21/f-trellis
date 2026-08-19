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

  # With the schema no longer declaring them, the definitions are the only place
  # a value type is stated.
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

  # A plain bag: the definitions already say each attribute's name and value type
  # in prose, and declaring them again in JSON Schema said nothing new.
  test "attributes are a name/value bag, not declared properties" do
    %w[entities relationships].each do |collection|
      attributes = schema.dig("properties", collection, "items", "properties", "attributes")

      assert_equal "object", attributes["type"]
      assert_nil attributes["properties"], "#{collection} still declares per-attribute properties"
      assert attributes["description"].present?
    end
  end

  # Walked rather than string-matched, so a nested declaration cannot hide.
  test "no value type is declared anywhere under attributes" do
    %w[entities relationships].each do |collection|
      attributes = schema.dig("properties", collection, "items", "properties", "attributes")

      assert_equal %w[description type], attributes.keys.sort,
                   "#{collection} attributes carry more than a type and a description"
      assert_equal "object", attributes["type"]
    end
  end


  # A source that does not state a value should produce no value rather than an
  # invented one.
  test "an entity requires an id, a name and a type, and no attribute" do
    entity = schema.dig("properties", "entities", "items")

    assert_equal %w[id name type], entity["required"]
    assert_nil entity.dig("properties", "attributes", "required")
  end

  test "an entity's type is constrained to this project's types" do
    types = schema.dig("properties", "entities", "items", "properties", "type", "enum")

    assert_equal @project.entity_types.pluck(:name).sort, types.sort
    assert_not_includes types, entity_types(:gemini_capsule).name
  end

  # Names repeat and vary between sentences; an id the model assigned does not.
  test "relationships reference entities by the ids the model assigned" do
    relationship = schema.dig("properties", "relationships", "items")

    assert_equal %w[type from to], relationship["required"]
    %w[from to].each do |end_name|
      description = relationship.dig("properties", end_name, "description")

      assert_match(/id of the entity/, description)
      assert_no_match(/name of the entity/, description)
    end
  end

  test "the instructions tell the model to mint ids and reference them" do
    text = @prompt.instructions

    assert_match(/short id of your own/i, text)
    assert_match(/unique within this response/i, text)
    assert_match(/Refer to entities in relationships by those ids/i, text)
  end

  # The old rule contradicting the new one is the specific failure mode here.
  test "the instructions no longer say to repeat the name" do
    assert_no_match(/by the same name you gave them/i, @prompt.instructions)
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

  # --- the worked example ----------------------------------------------------
  #
  # A schema says what shape is allowed; an example shows what a right answer
  # looks like.

  def example = JSON.parse(@prompt.example_json)

  # An invalid example is worse than none, so it is held to the same standard as
  # the schema: parsed, not pattern-matched.
  test "the example is valid JSON with two entities and one relationship" do
    assert_equal 2, example["entities"].size
    assert_equal 1, example["relationships"].size
  end

  # The thing the example exists to demonstrate, and the thing that would
  # silently rot if the id scheme changed again.
  test "the relationship's ends are the ids of the two entities" do
    ids = example["entities"].map { |e| e["id"] }
    edge = example["relationships"].first

    assert_equal ids.first, edge["from"]
    assert_equal ids.last, edge["to"]
    assert_not_equal edge["from"], edge["to"]
  end

  test "the example uses types the relationship type actually joins, in order" do
    type = @project.relationship_types.first
    edge = example["relationships"].first

    assert_equal type.name, edge["type"]
    assert_equal type.from_entity_type.name, example["entities"].first["type"]
    assert_equal type.to_entity_type.name, example["entities"].last["type"]
  end

  test "the example's attribute keys are real attributes of those types" do
    example["entities"].each do |entity|
      type = @project.entity_types.find_by!(name: entity["type"])
      declared = type.entity_type_attributes.active.pluck(:name)

      entity.fetch("attributes", {}).each_key do |key|
        assert_includes declared, key, "#{key} is not an attribute of #{type.name}"
      end
    end
  end

  test "attributes in the example are a flat bag, not nested objects" do
    example["entities"].each do |entity|
      entity.fetch("attributes", {}).each_value do |value|
        assert_not value.is_a?(Hash), "#{value.inspect} is nested; the bag is flat"
      end
    end
  end

  test "the prompt ends with the example" do
    assert_includes @prompt.to_s, @prompt.example_json
    assert @prompt.to_s.strip.end_with?(@prompt.example_json)
  end

  test "a project with no relationship types shows an entity-only example" do
    projects(:gemini).relationship_types.each { |t| t.relationships.destroy_all; t.destroy }

    example = JSON.parse(ExtractionPrompt.new(projects(:gemini).reload).example_json)

    assert_equal 1, example["entities"].size
    assert_empty example["relationships"]
  end
end
