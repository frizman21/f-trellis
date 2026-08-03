class CreatePersonPersonTypeTool < RubyLLM::Tool
  include RelationshipTypeCreation
  include CreatePersonPersonTypeContract

  # Takes the active report to match the other writing tools' shape, and ignores
  # it: a relationship type belongs to the knowledge base, not to the source that
  # happened to prompt it. See RelationshipTypeCreation.
  def initialize(_report = nil)
    super()
  end

  def execute(name:, description:, additional_attribute_keys: [])
    attrs, error = relationship_type_attributes(
      name: name, description: description,
      additional_attribute_keys: additional_attribute_keys
    )
    return error if error

    type, created = upsert_relationship_type(PersonPersonType, attrs)

    {
      person_person_type_id: type.id,
      name: type.name,
      created: created,
      additional_attribute_keys: type.additional_attribute_keys
    }
  rescue ActiveRecord::RecordInvalid => e
    { error: e.message }
  end
end
