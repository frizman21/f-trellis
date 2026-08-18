# `link_person_science` as an evaluation runs it: identical contract, no rows written.
# See RecordingUpsertPersonTool for why the stand-ins exist.
#
# The rejections are kept, not just the successes: the writing tool refuses an id
# it never issued and a relationship type that is not configured, and a stand-in
# that waved those through would credit a model for a link that could never
# exist. The type lookup is a read, so it writes nothing.
class RecordingLinkPersonScienceTool < RubyLLM::Tool
  include LinkPersonScienceContract

  def initialize(recorder)
    super()
    @recorder = recorder
  end

  def execute(person_id:, science_id:, type:, as_of: nil, confidence_tenths: 800,
              additional_attributes: {})
    return { error: "no person ##{person_id}" } unless @recorder.label_for(:person, person_id)
    return { error: "no science ##{science_id}" } unless @recorder.label_for(:science, science_id)

    type_name = type.to_s.strip
    return { error: "type is required" } if type_name.empty?

    relationship_type = PersonScienceType.find_by(name: type_name)
    return { error: "PersonScienceType '#{type_name}' is not configured" } unless relationship_type

    edge_id = @recorder.record_person_science(
      person_id: person_id, science_id: science_id,
      relationship_type: relationship_type.name, attributes: additional_attributes
    )

    {
      person_science_id: edge_id,
      detail_id: @recorder.next_detail_id,
      person_id: person_id,
      science_id: science_id,
      type: relationship_type.name
    }
  end
end
