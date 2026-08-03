# `create_person_person_type` as an evaluation runs it: identical contract, no
# rows written. See RecordingCreatePersonOrganizationTypeTool for why leaving
# invented vocabulary behind would break the comparison an evaluation exists for.
class RecordingCreatePersonPersonTypeTool < RubyLLM::Tool
  include RelationshipTypeCreation
  include CreatePersonPersonTypeContract

  def initialize(recorder)
    super()
    @recorder = recorder
  end

  def execute(name:, description:, additional_attribute_keys: [])
    attrs, error = relationship_type_attributes(
      name: name, description: description,
      additional_attribute_keys: additional_attribute_keys
    )
    return error if error

    existing = existing_relationship_type(PersonPersonType, attrs[:name])
    synthetic_id, first_time = @recorder.record_relationship_type(:person_person, name: attrs[:name])

    {
      person_person_type_id: existing&.id || synthetic_id,
      name: existing&.name || attrs[:name],
      created: existing.nil? && first_time,
      additional_attribute_keys: existing&.additional_attribute_keys || attrs[:additional_attribute_keys]
    }
  end
end
