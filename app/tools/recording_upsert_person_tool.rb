# `upsert_person` as an evaluation runs it: identical contract, no rows written.
#
# An evaluation is a rehearsal, and a rehearsal that writes people into the graph
# would poison the thing it measures. But measuring what a model *contributes*
# means seeing what it proposes, which means giving it the tools. The stand-in
# resolves that: the model sees the same tool name, description and schema, and
# gets back the same success shape with synthetic ids, so its behaviour is
# unchanged — while the entries land in a ProposalRecorder instead of in `people`.
class RecordingUpsertPersonTool < RubyLLM::Tool
  include UpsertPersonContract

  def initialize(recorder)
    super()
    @recorder = recorder
  end

  def execute(people:)
    entries = Array(people)
    return { error: "people must be a non-empty array" } if entries.empty?

    { results: entries.map { |entry| record_one(entry) } }
  end

  private

  def record_one(entry)
    attrs = EntityUpsert::Entry.new(entry)
    first = attrs.string(:first_name)
    last  = attrs.string(:last_name)
    return { error: "first_name and last_name are required" } if first.empty? || last.empty?

    person_id, created = @recorder.record_person(
      first_name: first, last_name: last,
      attributes: attrs.value(:additional_attributes)
    )

    { person_id: person_id, detail_id: @recorder.next_detail_id, created: created }
  end
end
