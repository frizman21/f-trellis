class UpsertScienceTool < RubyLLM::Tool
  include EntityUpsert
  # Name, description and schema live in the contract, shared with the recording
  # stand-in an evaluation runs.
  include UpsertScienceContract

  def initialize(report)
    super()
    @report = report
  end

  def execute(sciences:)
    entries = Array(sciences)
    return { error: "sciences must be a non-empty array" } if entries.empty?

    { results: entries.map { |entry| upsert_one(entry) } }
  end

  private

  def upsert_one(entry)
    attrs = EntityUpsert::Entry.new(entry)
    canonical = attrs.string(:name)
    return { error: "name is required" } if canonical.empty?

    types, unknown = resolve_types(ScienceType, attrs.value(:science_types))

    science, created = find_or_create_science(canonical)

    detail = ScienceDetail.create!(
      science: science,
      source_processing_report: @report,
      name: canonical,
      summary: attrs.string(:summary).presence,
      as_of: Time.current,
      confidence_tenths: clamp_confidence(attrs.value(:confidence_tenths)),
      additional_attributes: sanitize_attrs(attrs.value(:additional_attributes))
    )
    detail.science_types = types
    science.update!(current_detail: detail)

    { science_id: science.id, detail_id: detail.id, created: created,
      type_errors: unknown_type_notes("science type", unknown) }
  rescue ActiveRecord::RecordInvalid => e
    { error: e.message }
  end

  def find_or_create_science(name)
    existing = Science.joins(:current_detail)
                    .where("LOWER(science_details.name) = ?", name.downcase)
                    .first

    return [ existing, false ] if existing

    [ Science.create!, true ]
  end
end
