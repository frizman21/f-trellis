# `upsert_science` as an evaluation runs it: identical contract, no rows written.
# See RecordingUpsertPersonTool for why the stand-ins exist.
#
# The type lookup is a read, so it writes nothing — and reproducing it matters:
# a stand-in that accepted any type name would credit a model for a taxonomy
# entry the real run drops.
class RecordingUpsertScienceTool < RubyLLM::Tool
  include UpsertScienceContract

  def initialize(recorder)
    super()
    @recorder = recorder
  end

  def execute(sciences:)
    entries = Array(sciences)
    return { error: "sciences must be a non-empty array" } if entries.empty?

    { results: entries.map { |entry| record_one(entry) } }
  end

  private

  def record_one(entry)
    attrs = EntityUpsert::Entry.new(entry)
    canonical = attrs.string(:name)
    return { error: "name is required" } if canonical.empty?

    types, unknown = resolve_types(ScienceType, attrs.value(:science_types))

    science_id, created = @recorder.record_science(
      name: canonical,
      summary: attrs.string(:summary).presence,
      science_types: types.map(&:name),
      attributes: attrs.value(:additional_attributes)
    )

    { science_id: science_id, detail_id: @recorder.next_detail_id, created: created,
      type_errors: unknown_type_notes("science type", unknown) }
  end
end
