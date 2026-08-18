# `upsert_contract` as an evaluation runs it: identical contract, no rows
# written. See RecordingUpsertPersonTool for why the stand-ins exist.
class RecordingUpsertContractTool < RubyLLM::Tool
  include UpsertContractContract

  def initialize(recorder)
    super()
    @recorder = recorder
  end

  def execute(contracts:)
    entries = Array(contracts)
    return { error: "contracts must be a non-empty array" } if entries.empty?

    { results: entries.map { |entry| record_one(entry) } }
  end

  private

  def record_one(entry)
    attrs = EntityUpsert::Entry.new(entry)
    identifier = attrs.string(:identifier)
    return { error: "identifier is required" } if identifier.empty?

    types, unknown = resolve_types(ContractType, attrs.value(:contract_types))

    contract_id, created = @recorder.record_contract(
      identifier: identifier,
      title: attrs.string(:title).presence,
      value_usd: attrs.string(:value_usd).presence,
      contract_types: types.map(&:name),
      attributes: attrs.value(:additional_attributes)
    )

    { contract_id: contract_id, detail_id: @recorder.next_detail_id, created: created,
      type_errors: unknown_type_notes("contract type", unknown) }
  end
end
