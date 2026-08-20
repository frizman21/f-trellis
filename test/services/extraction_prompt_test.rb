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

  # A list of name/value pairs: the definitions already say each attribute's name
  # and value type in prose, and declaring a property per attribute says nothing
  # new while colliding when two types share a name (#67).
  test "attributes are a list of name/value pairs, not declared properties" do
    %w[entities relationships].each do |collection|
      attributes = schema.dig("properties", collection, "items", "properties", "attributes")
      item = attributes["items"]

      assert_equal "array", attributes["type"]
      assert attributes["description"].present?
      assert_equal %w[name value], item["properties"].keys.sort,
                   "#{collection} attribute items carry more than a name and a value"
      assert_equal %w[name value], item["required"].sort
    end
  end

  # The prose says an attribute's value type and TypedValue#cast_value enforces
  # it. A third statement in the schema is a third thing to disagree with the
  # other two, so every value is declared a plain string.
  test "no value type is declared anywhere under attributes" do
    %w[entities relationships].each do |collection|
      value = schema.dig("properties", collection, "items", "properties",
                         "attributes", "items", "properties", "value")

      assert_equal({ "type" => "string" }, value,
                   "#{collection} attribute values carry a declared type")
    end
  end

  # An attribute name the project has not declared is unrepresentable rather
  # than something the applier discards afterwards.
  test "attribute names are constrained to the ones the project declares" do
    names = schema.dig("properties", "entities", "items", "properties",
                       "attributes", "items", "properties", "name", "enum")

    assert_includes names, "thrust_kn"
    assert_not_includes names, "not_a_real_attribute"
  end

  test "a disabled attribute is not offered as a name" do
    entity_type_attributes(:engine_thrust).update!(is_disabled: true)

    names = JSON.parse(ExtractionPrompt.new(@project).schema_json)
                .dig("properties", "entities", "items", "properties",
                     "attributes", "items", "properties", "name", "enum")

    assert_not_includes names, "thrust_kn"
  end

  # An empty enum is invalid, and would surface as a provider error rather than
  # here. A project declaring no attributes must leave the enum out entirely.
  test "a project with no declared attributes omits the name enum" do
    project = Project.create!(name: "Attribute-free")
    bare = project.entity_types.create!(name: "Thing")
    project.relationship_types.create!(name: "Touches", from_entity_type: bare, to_entity_type: bare)

    name = JSON.parse(ExtractionPrompt.new(project).schema_json)
               .dig("properties", "entities", "items", "properties",
                    "attributes", "items", "properties", "name")

    assert_equal({ "type" => "string" }, name)
  end

  # The whole point of #67: the schema has to be expressible as a grammar the
  # provider can enforce. Walked rather than snapshotted, so it keeps holding as
  # types are added.
  test "every object in the schema is closed and fully required" do
    problems = []

    walk = lambda do |node, path|
      case node
      when Hash
        if node["type"] == "object"
          problems << "#{path}: additionalProperties is not false" unless node["additionalProperties"] == false
          missing = (node["properties"] || {}).keys - Array(node["required"])
          problems << "#{path}: properties not required: #{missing.inspect}" if missing.any?
        end
        problems << "#{path}: uses const" if node.key?("const")
        problems << "#{path}: empty enum" if node["enum"].is_a?(Array) && node["enum"].empty?
        node.each { |key, value| walk.call(value, "#{path}.#{key}") }
      when Array
        node.each_with_index { |value, i| walk.call(value, "#{path}[#{i}]") }
      end
    end

    walk.call(schema, "$")

    assert_empty problems, problems.join("\n")
  end


  # Everything is required, because a constrained grammar has no optional key.
  # "Nothing stated" is an empty list, which is what the instructions ask for.
  test "an entity requires an id, a name, a type and an attribute list" do
    entity = schema.dig("properties", "entities", "items")

    assert_equal %w[attributes id name type], entity["required"].sort
    assert_equal false, entity["additionalProperties"]
  end

  test "an entity's type is constrained to this project's types" do
    types = schema.dig("properties", "entities", "items", "properties", "type", "enum")

    assert_equal @project.entity_types.pluck(:name).sort, types.sort
    assert_not_includes types, entity_types(:gemini_capsule).name
  end

  # Names repeat and vary between sentences; an id the model assigned does not.
  test "relationships reference entities by the ids the model assigned" do
    relationship = schema.dig("properties", "relationships", "items")

    assert_equal %w[attributes from to type], relationship["required"].sort
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

  # The rule the database enforces (#11) is stated once, in prose. It used to be
  # repeated as an `ends` const in the schema, which read to a model as a field
  # it had to emit — and models emitted it, once per relationship (#67).
  test "a relationship declares no ends field" do
    relationship = schema.dig("properties", "relationships", "items")

    assert_nil relationship.dig("properties", "ends")
    assert_not_includes relationship["required"], "ends"
  end

  test "the prose still says which types each relationship joins" do
    assert_match(/Joins a Rocket Engine \(from\) to a Launch Vehicle \(to\)/, @prompt.to_s)
  end

  # --- the instructions ------------------------------------------------------

  test "tells the model to return only JSON and not to invent values" do
    text = @prompt.instructions

    # Whitespace-tolerant: the instructions are a wrapped heredoc, and where a
    # line happens to break is not what these assertions are about.
    assert_match(/return\s+only that JSON/i, text)
    assert_match(/Do not infer,\s+estimate, or fill a\s+gap/i, text)
    assert_match(/leave that attribute out of the list/i, text)
    assert_match(/the list is\s+empty/i, text)
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

  test "the example's attribute names are real attributes of those types" do
    example["entities"].each do |entity|
      type = @project.entity_types.find_by!(name: entity["type"])
      declared = type.entity_type_attributes.active.pluck(:name)

      entity.fetch("attributes").each do |pair|
        assert_includes declared, pair["name"], "#{pair['name']} is not an attribute of #{type.name}"
      end
    end
  end

  # The example must not contradict the structure printed above it — that gap is
  # where a model improvises.
  test "the example's attributes are name/value pairs with scalar values" do
    example["entities"].each do |entity|
      assert_kind_of Array, entity["attributes"]

      entity["attributes"].each do |pair|
        assert_equal %w[name value], pair.keys.sort
        assert_kind_of String, pair["value"], "#{pair['value'].inspect} is not a string"
      end
    end
  end

  # Required means present, so a type with nothing to show still carries a list.
  # Bare Type declares no attributes, and the example is built from Bare
  # Relation, which is the first relationship type by name.
  test "the example carries an attribute list even for a type with no attributes" do
    bare = example["entities"].find { |entity| entity["type"] == entity_types(:bare).name }

    assert_not_nil bare, "the example does not include the attribute-free type"
    assert_equal [], bare["attributes"]
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

  # --- deleted types (#66) ---------------------------------------------------

  # The failure with a bill attached: a prompt naming a deleted type spends
  # input tokens on every source asking a model for something nobody wants back.
  test "omits a deleted entity type from the definitions, the enum and the example" do
    entity_types(:rocket_engine).discard_with_entities

    text = ExtractionPrompt.new(@project).to_s

    assert_not_includes text, "Rocket Engine"
  end

  test "omits a deleted relationship type" do
    relationship_types(:powers).discard_with_relationships

    text = ExtractionPrompt.new(@project).to_s

    assert_not_includes text, "Powers"
  end

  # A relationship type naming a deleted entity type would be a rule no reply
  # could satisfy. The cascade removes it; this is the prompt-side proof.
  test "omits a relationship type whose end was deleted" do
    entity_types(:launch_vehicle).discard_with_entities

    text = ExtractionPrompt.new(@project).to_s

    assert_not_includes text, "Powers"
    assert_not_includes text, "Launch Vehicle"
  end

  # ExtractionJob raises NotRunnable on a blank prompt rather than sending an
  # instructionless one.
  test "is empty when every type is deleted" do
    @project.relationship_types.kept.each(&:discard_with_relationships)
    @project.entity_types.kept.each(&:discard_with_entities)

    assert_predicate ExtractionPrompt.new(@project), :empty?
  end
end
