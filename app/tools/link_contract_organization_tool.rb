class LinkContractOrganizationTool < RubyLLM::Tool
  include LinkContractOrganizationContract

  def initialize(report)
    super()
    @report = report
  end

  def execute(contract_id:, organization_id:, type:, as_of: nil, confidence_tenths: 800, additional_attributes: {})
    contract = Contract.find_by(id: contract_id)
    return { error: "no contract ##{contract_id}" } unless contract

    organization = Organization.find_by(id: organization_id)
    return { error: "no organization ##{organization_id}" } unless organization

    type_name = type.to_s.strip
    return { error: "type is required" } if type_name.empty?

    relationship_type = ContractOrganizationType.find_by(name: type_name)
    return { error: "ContractOrganizationType '#{type_name}' is not configured" } unless relationship_type

    edge = ContractOrganization.find_or_create_by!(contract: contract, organization: organization)

    detail = ContractOrganizationDetail.create!(
      contract_organization: edge,
      source_processing_report: @report,
      as_of: parse_as_of(as_of),
      confidence_tenths: clamp_confidence(confidence_tenths),
      additional_attributes: sanitize_attrs(additional_attributes)
    )

    detail.contract_organization_types = [ relationship_type ]
    edge.update!(current_detail: detail)

    {
      contract_organization_id: edge.id,
      detail_id: detail.id,
      contract_id: contract.id,
      organization_id: organization.id,
      type: relationship_type.name
    }
  rescue ActiveRecord::RecordInvalid => e
    { error: e.message }
  end

  private

  def parse_as_of(value)
    return Time.current if value.blank?

    Time.zone.parse(value.to_s) || Time.current
  rescue ArgumentError
    Time.current
  end

  def clamp_confidence(value)
    [ [ value.to_i, 0 ].max, 1000 ].min
  end

  def sanitize_attrs(attrs)
    return {} unless attrs.is_a?(Hash)

    attrs.each_with_object({}) do |(k, v), out|
      next unless v.is_a?(String) || v.is_a?(Numeric) || v == true || v == false
      out[k.to_s] = v
    end
  end
end
