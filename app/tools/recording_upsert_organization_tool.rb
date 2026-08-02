# `upsert_organization` as an evaluation runs it: identical contract, no rows
# written. See RecordingUpsertPersonTool for why the stand-ins exist.
class RecordingUpsertOrganizationTool < RubyLLM::Tool
  include UpsertOrganizationContract

  def initialize(recorder)
    super()
    @recorder = recorder
  end

  def execute(organizations:)
    entries = Array(organizations)
    return { error: "organizations must be a non-empty array" } if entries.empty?

    { results: entries.map { |entry| record_one(entry) } }
  end

  private

  def record_one(entry)
    attrs = EntityUpsert::Entry.new(entry)
    canonical = attrs.string(:name)
    return { error: "name is required" } if canonical.empty?

    organization_id, created = @recorder.record_organization(
      name: canonical,
      acronym: attrs.string(:acronym).presence,
      attributes: attrs.value(:additional_attributes)
    )

    { organization_id: organization_id, detail_id: @recorder.next_detail_id, created: created }
  end
end
