# `link_person_person` as an evaluation runs it: identical contract, no rows
# written. See RecordingLinkPersonOrganizationTool for why the rejections are
# kept rather than only the successes.
class RecordingLinkPersonPersonTool < RubyLLM::Tool
  include LinkPersonPersonContract

  def initialize(recorder)
    super()
    @recorder = recorder
  end

  def execute(person_a_id:, person_b_id:, type:, as_of: nil, confidence_tenths: 800,
              additional_attributes: {})
    return { error: "person_a_id and person_b_id must be different" } if person_a_id == person_b_id
    return { error: "no person ##{person_a_id}" } unless @recorder.label_for(:person, person_a_id)
    return { error: "no person ##{person_b_id}" } unless @recorder.label_for(:person, person_b_id)

    type_name = type.to_s.strip
    return { error: "type is required" } if type_name.empty?

    # Configured already, or minted by `create_person_person_type` earlier in
    # this run — the writing run would have created that type for real, so
    # refusing the link here would fail a model for a sequence that works.
    relationship_type = PersonPersonType.find_by(name: type_name)
    unless relationship_type || @recorder.minted_relationship_type?(:person_person, type_name)
      return { error: "PersonPersonType '#{type_name}' is not configured" }
    end

    edge_id = @recorder.record_person_person(
      person_a_id: person_a_id, person_b_id: person_b_id,
      relationship_type: relationship_type&.name || type_name, attributes: additional_attributes
    )

    {
      person_person_id: edge_id,
      detail_id: @recorder.next_detail_id,
      person_a_id: person_a_id,
      person_b_id: person_b_id,
      type: relationship_type&.name || type_name
    }
  end
end
