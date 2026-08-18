# `link_part_technology` as an evaluation runs it: identical contract, no rows written.
# See RecordingUpsertPersonTool for why the stand-ins exist.
#
# The rejections are kept, not just the successes: the writing tool refuses an id
# it never issued and a relationship type that is not configured, and a stand-in
# that waved those through would credit a model for a link that could never
# exist. The type lookup is a read, so it writes nothing.
class RecordingLinkPartTechnologyTool < RubyLLM::Tool
  include LinkPartTechnologyContract

  def initialize(recorder)
    super()
    @recorder = recorder
  end

  def execute(part_id:, technology_id:, type:, as_of: nil, confidence_tenths: 800,
              additional_attributes: {})
    return { error: "no part ##{part_id}" } unless @recorder.label_for(:part, part_id)
    return { error: "no technology ##{technology_id}" } unless @recorder.label_for(:technology, technology_id)

    type_name = type.to_s.strip
    return { error: "type is required" } if type_name.empty?

    relationship_type = PartTechnologyType.find_by(name: type_name)
    return { error: "PartTechnologyType '#{type_name}' is not configured" } unless relationship_type

    edge_id = @recorder.record_part_technology(
      part_id: part_id, technology_id: technology_id,
      relationship_type: relationship_type.name, attributes: additional_attributes
    )

    {
      part_technology_id: edge_id,
      detail_id: @recorder.next_detail_id,
      part_id: part_id,
      technology_id: technology_id,
      type: relationship_type.name
    }
  end
end
