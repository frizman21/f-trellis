class LinkContractPersonTool < RubyLLM::Tool
  include LinkContractPersonContract

  def initialize(report)
    super()
    @report = report
  end

  def execute(contract_id:, person_id:, type:, as_of: nil, confidence_tenths: 800, additional_attributes: {})
    contract = Contract.find_by(id: contract_id)
    return { error: "no contract ##{contract_id}" } unless contract

    person = Person.find_by(id: person_id)
    return { error: "no person ##{person_id}" } unless person

    type_name = type.to_s.strip
    return { error: "type is required" } if type_name.empty?

    relationship_type = ContractPersonType.find_by(name: type_name)
    return { error: "ContractPersonType '#{type_name}' is not configured" } unless relationship_type

    edge = ContractPerson.find_or_create_by!(contract: contract, person: person)

    detail = ContractPersonDetail.create!(
      contract_person: edge,
      source_processing_report: @report,
      as_of: parse_as_of(as_of),
      confidence_tenths: clamp_confidence(confidence_tenths),
      additional_attributes: sanitize_attrs(additional_attributes)
    )

    detail.contract_person_types = [ relationship_type ]
    edge.update!(current_detail: detail)

    {
      contract_person_id: edge.id,
      detail_id: detail.id,
      contract_id: contract.id,
      person_id: person.id,
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
