# `link_part_organization` as an evaluation runs it: identical contract, no rows
# written. See RecordingUpsertPersonTool for why the stand-ins exist.
#
# The rejections are kept, not just the successes. The writing tool refuses an id
# it never issued and a relationship type that is not configured; a stand-in that
# waved those through would let a model get away with something the real run
# rejects, and the evaluation would credit it for a link that could never exist.
# The type lookup is a read, so it writes nothing.
#
# Unlike the person↔organization stand-in there is no minted-type case to allow:
# Manufacturer, Consumer and Demand are a closed set, and no tool lets a model
# add to it.
class RecordingLinkPartOrganizationTool < RubyLLM::Tool
  include LinkPartOrganizationContract

  def initialize(recorder)
    super()
    @recorder = recorder
  end

  def execute(part_id:, organization_id:, type:, as_of: nil, confidence_tenths: 800,
              additional_attributes: {})
    return { error: "no part ##{part_id}" } unless @recorder.label_for(:part, part_id)
    return { error: "no organization ##{organization_id}" } unless @recorder.label_for(:organization, organization_id)

    type_name = type.to_s.strip
    return { error: "type is required" } if type_name.empty?

    relationship_type = PartOrganizationType.find_by(name: type_name)
    return { error: "PartOrganizationType '#{type_name}' is not configured" } unless relationship_type

    edge_id = @recorder.record_part_organization(
      part_id: part_id, organization_id: organization_id,
      relationship_type: relationship_type.name, attributes: additional_attributes
    )

    {
      part_organization_id: edge_id,
      detail_id: @recorder.next_detail_id,
      part_id: part_id,
      organization_id: organization_id,
      type: relationship_type.name
    }
  end
end
