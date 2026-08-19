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
    # Active only: the prompt asks for what the project tracks now.
    @entity_types = project.entity_types.includes(:entity_type_attributes).to_a
    @relationship_types = project.relationship_types
                                 .includes(:relationship_type_attributes,
                                           :from_entity_type, :to_entity_type).to_a
  end

  attr_reader :project, :entity_types, :relationship_types

  def empty? = entity_types.empty? && relationship_types.empty?

  # The whole prompt, as the model would receive it.
  def to_s
    [ instructions, definitions, schema_section ].compact_blank.join("\n\n")
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
        for an attribute, omit that attribute. Do not infer, estimate, or fill a
        gap from your own knowledge.
      - Every entity needs a name and a type. The name is what the source calls
        the thing.
      - Refer to entities in relationships by the same name you gave them in the
        entities list.
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

  def schema
    {
      "type" => "object",
      "required" => %w[entities relationships],
      "properties" => {
        "entities" => { "type" => "array", "items" => entity_schema },
        "relationships" => { "type" => "array", "items" => relationship_schema }
      }
    }
  end

  private

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

  # name and type are required; attributes are not. A source that does not state
  # a value should produce no value rather than an invented one, and the
  # instructions say so too — a schema alone does not stop a model filling gaps.
  def entity_schema
    {
      "type" => "object",
      "required" => %w[name type],
      "properties" => {
        "name" => { "type" => "string", "description" => "What the source calls this thing." },
        "type" => { "type" => "string", "enum" => entity_types.map(&:name) },
        "attributes" => attribute_bag("entity")
      }
    }
  end

  # A plain name/value bag rather than a declared property per attribute. The
  # definitions above already say each attribute's name and value type in prose;
  # declaring them again in JSON Schema said nothing new and made the schema as
  # long as the ontology.
  #
  # It was also quietly wrong: flattening every type's attributes into one
  # properties map collides when two types share an attribute name with different
  # value types, and the first one written wins. A bag makes no such claim.
  def attribute_bag(subject)
    {
      "type" => "object",
      "description" => "The attributes this #{subject} has, as name and value. " \
                       "Use the attribute names given in the definitions above, and " \
                       "include only the ones the source states."
    }
  end

  # Entities are referenced by name: the model is reading a page and has no ids.
  # The ends carry the same constraint the database enforces (#11).
  def relationship_schema
    {
      "type" => "object",
      "required" => %w[type from to],
      "properties" => {
        "type" => { "type" => "string", "enum" => relationship_types.map(&:name) },
        "from" => { "type" => "string", "description" => "The name of the entity at the from end." },
        "to" => { "type" => "string", "description" => "The name of the entity at the to end." },
        "ends" => {
          "description" => "Which entity types each relationship type may join.",
          "const" => relationship_types.to_h { |type|
            [ type.name, { "from" => type.from_entity_type.name, "to" => type.to_entity_type.name } ]
          }
        },
        "attributes" => attribute_bag("relationship")
      }
    }
  end
end
