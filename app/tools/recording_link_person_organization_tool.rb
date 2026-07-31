# `link_person_organization` as an evaluation runs it: identical contract, no
# rows written. See RecordingUpsertPersonTool for why the stand-ins exist.
#
# The rejections are kept, not just the successes. The writing tool refuses an id
# it never issued and a relationship type that is not configured; a stand-in that
# waved those through would let a model get away with something the real run
# rejects, and the evaluation would credit it for a link that could never exist.
# The type lookup is a read, so it writes nothing.
class RecordingLinkPersonOrganizationTool < RubyLLM::Tool
  include LinkPersonOrganizationContract

  def initialize(recorder)
    super()
    @recorder = recorder
  end

  def execute(person_id:, organization_id:, type:, as_of: nil, confidence_tenths: 800,
              additional_attributes: {})
    return { error: "no person ##{person_id}" } unless @recorder.label_for(:person, person_id)
    return { error: "no organization ##{organization_id}" } unless @recorder.label_for(:organization, organization_id)

    type_name = type.to_s.strip
    return { error: "type is required" } if type_name.empty?

    relationship_type = PersonOrganizationType.find_by(name: type_name)
    return { error: "PersonOrganizationType '#{type_name}' is not configured" } unless relationship_type

    edge_id = @recorder.record_person_organization(
      person_id: person_id, organization_id: organization_id,
      relationship_type: relationship_type.name, attributes: additional_attributes
    )

    {
      person_organization_id: edge_id,
      detail_id: @recorder.next_detail_id,
      person_id: person_id,
      organization_id: organization_id,
      type: relationship_type.name
    }
  end
end
