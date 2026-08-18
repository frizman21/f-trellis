# `link_contract_organization` as an evaluation runs it: identical contract, no rows written.
# See RecordingUpsertPersonTool for why the stand-ins exist.
#
# The rejections are kept, not just the successes: the writing tool refuses an id
# it never issued and a relationship type that is not configured, and a stand-in
# that waved those through would credit a model for a link that could never
# exist. The type lookup is a read, so it writes nothing.
class RecordingLinkContractOrganizationTool < RubyLLM::Tool
  include LinkContractOrganizationContract

  def initialize(recorder)
    super()
    @recorder = recorder
  end

  def execute(contract_id:, organization_id:, type:, as_of: nil, confidence_tenths: 800,
              additional_attributes: {})
    return { error: "no contract ##{contract_id}" } unless @recorder.label_for(:contract, contract_id)
    return { error: "no organization ##{organization_id}" } unless @recorder.label_for(:organization, organization_id)

    type_name = type.to_s.strip
    return { error: "type is required" } if type_name.empty?

    relationship_type = ContractOrganizationType.find_by(name: type_name)
    return { error: "ContractOrganizationType '#{type_name}' is not configured" } unless relationship_type

    edge_id = @recorder.record_contract_organization(
      contract_id: contract_id, organization_id: organization_id,
      relationship_type: relationship_type.name, attributes: additional_attributes
    )

    {
      contract_organization_id: edge_id,
      detail_id: @recorder.next_detail_id,
      contract_id: contract_id,
      organization_id: organization_id,
      type: relationship_type.name
    }
  end
end
