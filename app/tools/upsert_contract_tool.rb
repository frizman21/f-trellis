class UpsertContractTool < RubyLLM::Tool
  include EntityUpsert
  # Name, description and schema live in the contract module, shared with the
  # recording stand-in an evaluation runs.
  include UpsertContractContract

  def initialize(report)
    super()
    @report = report
  end

  def execute(contracts:)
    entries = Array(contracts)
    return { error: "contracts must be a non-empty array" } if entries.empty?

    { results: entries.map { |entry| upsert_one(entry) } }
  end

  private

  def upsert_one(entry)
    attrs = EntityUpsert::Entry.new(entry)
    identifier = attrs.string(:identifier)
    return { error: "identifier is required" } if identifier.empty?

    types, unknown = resolve_types(ContractType, attrs.value(:contract_types))

    contract, created = find_or_create_contract(identifier)

    detail = ContractDetail.create!(
      contract: contract,
      source_processing_report: @report,
      identifier: identifier,
      title: attrs.string(:title).presence,
      value_usd: parse_money(attrs.string(:value_usd)),
      start_date: parse_date(attrs.string(:start_date)),
      end_date: parse_date(attrs.string(:end_date)),
      as_of: Time.current,
      confidence_tenths: clamp_confidence(attrs.value(:confidence_tenths)),
      additional_attributes: sanitize_attrs(attrs.value(:additional_attributes))
    )
    detail.contract_types = types
    contract.update!(current_detail: detail)

    { contract_id: contract.id, detail_id: detail.id, created: created,
      type_errors: unknown_type_notes("contract type", unknown) }
  rescue ActiveRecord::RecordInvalid => e
    { error: e.message }
  end

  # Tolerates the thousands separators and currency symbol a page puts around
  # the digits. Refuses anything with no number in it rather than storing a
  # silent zero — the same rule UpsertPartTool applies to a specification.
  def parse_money(value)
    return nil if value.blank?

    cleaned = value.tr(",$", "").strip
    match = cleaned.match(/\d+(?:\.\d+)?/)
    return nil if match.nil?

    BigDecimal(match[0])
  end

  def parse_date(value)
    return nil if value.blank?

    Date.parse(value)
  rescue Date::Error
    nil
  end

  def find_or_create_contract(identifier)
    existing = Contract.joins(:current_detail)
                       .where("LOWER(contract_details.identifier) = ?", identifier.downcase)
                       .first

    return [ existing, false ] if existing

    [ Contract.create!, true ]
  end
end
