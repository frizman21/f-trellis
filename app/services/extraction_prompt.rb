# The instructions used to extract information from a source for one project,
# generated from that project's structure.
#
# A service rather than a template: the prompt is a value derived from a project,
# wanted as text in a view now and by an extraction job later, and building it in
# ERB would mean rebuilding it somewhere else the day something runs it.
#
# Nothing is stored. The prompt is what the project's structure currently
# implies, so it cannot drift from that structure the way a saved copy would.
class ExtractionPrompt
  def initialize(project)
    @project = project
    # Active and undeleted only: the prompt asks for what the project tracks
    # now. A deleted type left in here is paid for on every source — tokens
    # spent asking a model for a kind of thing nobody wants back.
    @entity_types = project.entity_types.kept.includes(:entity_type_attributes).to_a
    @relationship_types = project.relationship_types.kept
                                 .includes(:relationship_type_attributes,
                                           :from_entity_type, :to_entity_type).to_a
  end

  attr_reader :project, :entity_types, :relationship_types

  def empty? = entity_types.empty? && relationship_types.empty?

  # The whole prompt, as the model would receive it.
  def to_s
    [ instructions, definitions, schema_section, example_section ].compact_blank.join("\n\n")
  end

  def instructions
    <<~TEXT.strip
      You are reading a source document and extracting the things it describes for
      the "#{project.name}" knowledge base.

      Read the content that follows the instructions. Identify every entity and
      every relationship it describes that matches one of the definitions below.
      Populate the JSON structure at the end of these instructions and return
      only that JSON — no explanation, no commentary, no markdown fence.

      Rules:

      - Record only what the source states. If the source does not give a value
        for an attribute, leave that attribute out of the list. Do not infer,
        estimate, or fill a gap from your own knowledge.
      - Attributes are a list of name and value pairs, and every entity and
        relationship carries one. Where the source states nothing, the list is
        empty — the key is still there.
      - Every entity needs an id, a name, and a type. The name is what the source
        calls the thing.
      - Give each entity a short id of your own — e1, e2, org-nasa, whatever is
        readable — unique within this response. These ids are yours: they mean
        nothing outside this reply and are not database identifiers.
      - Refer to entities in relationships by those ids, never by name. Names
        repeat and vary between sentences; an id you assigned does not.
      - A relationship may only join the entity types its definition names, in
        the direction it names.
      - If the source describes nothing that matches a definition, return the
        structure with empty lists.
    TEXT
  end

  # What counts as one of each thing. The description is the definition — this is
  # the use the type forms describe when they say the description is the context
  # for extraction.
  def definitions
    return nil if empty?

    sections = []
    sections << entity_definitions if entity_types.any?
    sections << relationship_definitions if relationship_types.any?
    sections.join("\n\n")
  end

  def schema_section
    return nil if empty?

    "The JSON structure to return:\n\n#{schema_json}"
  end

  def schema_json = JSON.pretty_generate(schema)

  def example_section
    return nil if empty?

    "An example of a correct reply, using this project's own types:" \
      "\n\n#{example_json}"
  end

  def example_json = JSON.pretty_generate(example)

  # A schema says what shape is allowed; an example shows what a right answer
  # looks like. The gap between them is where a model improvises — over where the
  # ids go, that attributes is a flat bag rather than a nested object, and that a
  # relationship's ends are ids rather than names.
  #
  # Built from a relationship type rather than from two entity types picked at
  # random, because a random pair may be one no relationship type can join, and
  # an example that contradicts the rules above it is worse than none.
  def example
    pair = relationship_types.first

    if pair.nil?
      return { "entities" => [ example_entity(entity_types.first, "e1") ].compact,
               "relationships" => [] }
    end

    {
      "entities" => [
        example_entity(pair.from_entity_type, "e1"),
        example_entity(pair.to_entity_type, "e2")
      ],
      "relationships" => [
        {
          "type" => pair.name,
          "from" => "e1",
          "to" => "e2"
        }.merge(example_attributes(pair.relationship_type_attributes.active))
      ]
    }
  end

  private

  def example_entity(type, id)
    return nil if type.nil?

    {
      "id" => id,
      "name" => "The name the source gives this #{type.name}",
      "type" => type.name
    }.merge(example_attributes(type.entity_type_attributes.active))
  end

  # Illustrative placeholders by value type: the example should show the shape of
  # a value without inventing facts that read as real data about real things.
  #
  # Always present, even when empty. The schema requires the key, and an example
  # that omitted it would contradict the structure printed directly above it —
  # which is the gap a model improvises into.
  def example_attributes(attributes)
    list = attributes.to_a.first(3).map do |a|
      { "name" => a.name, "value" => example_value(a) }
    end

    { "attributes" => list }
  end

  # Strings throughout, because `value` is a string in the schema. The declared
  # value type is stated in the prose definitions and enforced by
  # TypedValue#cast_value on the way in; saying it a third time in the schema
  # would be a third place for it to disagree with the other two.
  def example_value(attribute)
    case attribute.value_type
    when "int" then "1"
    when "float" then "1.5"
    when "datetime" then "1969-07-16T13:32:00Z"
    else "the #{attribute.name} the source states"
    end
  end

  # Every object closes itself and requires every property it declares. That is
  # what makes this expressible as a grammar the provider can enforce, rather
  # than a shape a model is asked to observe — see #67. A reply that is not this
  # shape becomes unrepresentable instead of merely wrong.
  def schema
    {
      "type" => "object",
      "additionalProperties" => false,
      "required" => %w[entities relationships],
      "properties" => {
        "entities" => { "type" => "array", "items" => entity_schema },
        "relationships" => { "type" => "array", "items" => relationship_schema }
      }
    }
  end


  def entity_definitions
    lines = [ "Entity types:" ]

    entity_types.each do |type|
      lines << ""
      lines << "- #{type.name}: #{type.description.presence || 'No definition given.'}"
      type.entity_type_attributes.active.each do |attribute|
        lines << "    - #{attribute.name} (#{attribute.value_type}), optional"
      end
    end

    lines.join("\n")
  end

  def relationship_definitions
    lines = [ "Relationship types:" ]

    relationship_types.each do |type|
      lines << ""
      lines << "- #{type.name}: #{type.description.presence || 'No definition given.'}"
      lines << "    Joins #{with_article(type.from_entity_type.name)} (from) to " \
               "#{with_article(type.to_entity_type.name)} (to)."
      type.relationship_type_attributes.active.each do |attribute|
        lines << "    - #{attribute.name} (#{attribute.value_type}), optional"
      end
    end

    lines.join("\n")
  end

  # "an Organization", not "a Organization". The prompt is prose a model reads,
  # and prose that reads as carelessly written invites careless output.
  def with_article(name)
    article = name.match?(/\A[aeiou]/i) ? "an" : "a"
    "#{article} #{name}"
  end

  # Everything is required, including attributes — a constrained grammar has no
  # notion of an optional key. "Nothing stated" is an empty list, which the
  # instructions say as well, because a schema alone does not stop a model
  # filling gaps and an empty list is the thing to fill them with.
  def entity_schema
    {
      "type" => "object",
      "additionalProperties" => false,
      "required" => %w[id name type attributes],
      "properties" => {
        # The model's own id, not a database one. Names repeat and vary between
        # sentences; an id the model assigned is unambiguous and cheap to repeat
        # exactly five hundred tokens later.
        "id" => { "type" => "string",
                  "description" => "A short id you assign, unique within this response." },
        "name" => { "type" => "string", "description" => "What the source calls this thing." },
        "type" => { "type" => "string", "enum" => entity_types.map(&:name) },
        "attributes" => attribute_list("entity", entity_attribute_names)
      }
    }
  end

  # A list of name/value pairs rather than a declared property per attribute.
  # The definitions above already say each attribute's name and value type in
  # prose; declaring them again in JSON Schema says nothing new and makes the
  # schema as long as the ontology.
  #
  # It would also be quietly wrong: flattening every type's attributes into one
  # properties map collides when two types share an attribute name with
  # different value types, and the first one written wins. A name carried as
  # *data* makes no such claim, which is what lets one list serve every type.
  #
  # It was an open object until #67. That shape cannot be expressed as a
  # constrained grammar — a provider has no way to describe "an object whose
  # keys I do not know" — so the reply could not be enforced, only requested.
  #
  # The enum closes a gap the open shape never could: an attribute name the
  # project has not declared becomes unrepresentable rather than something the
  # applier discards afterwards. Omitted entirely when a project declares no
  # attributes, because an empty enum is invalid and would fail validation at
  # the provider rather than here.
  def attribute_list(subject, names)
    name_schema = { "type" => "string" }
    name_schema["enum"] = names if names.any?

    {
      "type" => "array",
      "description" => "The attributes this #{subject} has, as name and value. " \
                       "Use the attribute names given in the definitions above, " \
                       "and include only the ones the source states.",
      "items" => {
        "type" => "object",
        "additionalProperties" => false,
        "required" => %w[name value],
        "properties" => {
          "name" => name_schema,
          # A string whatever the declared type. The prose says what the type is
          # and TypedValue#cast_value enforces it on the way in; a third statement
          # here would be a third place for the three to disagree.
          "value" => { "type" => "string" }
        }
      }
    }
  end

  def entity_attribute_names
    entity_types.flat_map { |type| type.entity_type_attributes.active.map(&:name) }.uniq.sort
  end

  def relationship_attribute_names
    relationship_types.flat_map { |type| type.relationship_type_attributes.active.map(&:name) }.uniq.sort
  end

  # Entities are referenced by the ids the model assigned in the entities list.
  #
  # Which types a relationship may join is stated once, in the prose definitions
  # above ("Joins an Organization (from) to a Person (to)"). It used to be
  # repeated here as an `ends` property carrying a `const`, which read to a model
  # as a field it was required to emit — and models emitted it, echoing the whole
  # table once per relationship into output tokens. Removed in #67; the
  # constraint is unchanged and the database still enforces it (#11).
  def relationship_schema
    {
      "type" => "object",
      "additionalProperties" => false,
      "required" => %w[type from to attributes],
      "properties" => {
        "type" => { "type" => "string", "enum" => relationship_types.map(&:name) },
        "from" => { "type" => "string", "description" => "The id of the entity at the from end." },
        "to" => { "type" => "string", "description" => "The id of the entity at the to end." },
        "attributes" => attribute_list("relationship", relationship_attribute_names)
      }
    }
  end
end
