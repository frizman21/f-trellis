# `create_person_organization_type` as an evaluation runs it: identical contract,
# no rows written. See RecordingUpsertPersonTool for why the stand-ins exist.
#
# Vocabulary is the one thing an evaluation must be *especially* careful not to
# write. A rehearsal that left its invented types behind would change the tool
# description every later run reads, so the runs would no longer be comparable —
# and the second model would be graded against a list the first one wrote.
class RecordingCreatePersonOrganizationTypeTool < RubyLLM::Tool
  include RelationshipTypeCreation
  include CreatePersonOrganizationTypeContract

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

    # A read, so it writes nothing — and it is what makes `created` honest: the
    # writing tool hands back the existing type for a name already configured.
    existing = existing_relationship_type(PersonOrganizationType, attrs[:name])
    synthetic_id, first_time = @recorder.record_relationship_type(:person_organization, name: attrs[:name])

    {
      person_organization_type_id: existing&.id || synthetic_id,
      name: existing&.name || attrs[:name],
      created: existing.nil? && first_time,
      additional_attribute_keys: existing&.additional_attribute_keys || attrs[:additional_attribute_keys]
    }
  end
end
