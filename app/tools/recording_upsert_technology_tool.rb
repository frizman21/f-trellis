# `upsert_technology` as an evaluation runs it: identical contract, no rows written.
# See RecordingUpsertPersonTool for why the stand-ins exist.
#
# The type lookup is a read, so it writes nothing — and reproducing it matters:
# a stand-in that accepted any type name would credit a model for a taxonomy
# entry the real run drops.
class RecordingUpsertTechnologyTool < RubyLLM::Tool
  include UpsertTechnologyContract

  def initialize(recorder)
    super()
    @recorder = recorder
  end

  def execute(technologies:)
    entries = Array(technologies)
    return { error: "technologies must be a non-empty array" } if entries.empty?

    { results: entries.map { |entry| record_one(entry) } }
  end

  private

  def record_one(entry)
    attrs = EntityUpsert::Entry.new(entry)
    canonical = attrs.string(:name)
    return { error: "name is required" } if canonical.empty?

    types, unknown = resolve_types(TechnologyType, attrs.value(:technology_types))

    technology_id, created = @recorder.record_technology(
      name: canonical,
      summary: attrs.string(:summary).presence,
      technology_types: types.map(&:name),
      attributes: attrs.value(:additional_attributes)
    )

    { technology_id: technology_id, detail_id: @recorder.next_detail_id, created: created,
      type_errors: unknown_type_notes("technology type", unknown) }
  end
end
