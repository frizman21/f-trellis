# `link_contract_person` as an evaluation runs it: identical contract, no rows written.
# See RecordingUpsertPersonTool for why the stand-ins exist.
#
# The rejections are kept, not just the successes: the writing tool refuses an id
# it never issued and a relationship type that is not configured, and a stand-in
# that waved those through would credit a model for a link that could never
# exist. The type lookup is a read, so it writes nothing.
class RecordingLinkContractPersonTool < RubyLLM::Tool
  include LinkContractPersonContract

  def initialize(recorder)
    super()
    @recorder = recorder
  end

  def execute(contract_id:, person_id:, type:, as_of: nil, confidence_tenths: 800,
              additional_attributes: {})
    return { error: "no contract ##{contract_id}" } unless @recorder.label_for(:contract, contract_id)
    return { error: "no person ##{person_id}" } unless @recorder.label_for(:person, person_id)

    type_name = type.to_s.strip
    return { error: "type is required" } if type_name.empty?

    relationship_type = ContractPersonType.find_by(name: type_name)
    return { error: "ContractPersonType '#{type_name}' is not configured" } unless relationship_type

    edge_id = @recorder.record_contract_person(
      contract_id: contract_id, person_id: person_id,
      relationship_type: relationship_type.name, attributes: additional_attributes
    )

    {
      contract_person_id: edge_id,
      detail_id: @recorder.next_detail_id,
      contract_id: contract_id,
      person_id: person_id,
      type: relationship_type.name
    }
  end
end
