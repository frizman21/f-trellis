class UpsertTechnologyTool < RubyLLM::Tool
  include EntityUpsert
  # Name, description and schema live in the contract, shared with the recording
  # stand-in an evaluation runs.
  include UpsertTechnologyContract

  def initialize(report)
    super()
    @report = report
  end

  def execute(technologies:)
    entries = Array(technologies)
    return { error: "technologies must be a non-empty array" } if entries.empty?

    { results: entries.map { |entry| upsert_one(entry) } }
  end

  private

  def upsert_one(entry)
    attrs = EntityUpsert::Entry.new(entry)
    canonical = attrs.string(:name)
    return { error: "name is required" } if canonical.empty?

    types, unknown = resolve_types(TechnologyType, attrs.value(:technology_types))

    technology, created = find_or_create_technology(canonical)

    detail = TechnologyDetail.create!(
      technology: technology,
      source_processing_report: @report,
      name: canonical,
      summary: attrs.string(:summary).presence,
      as_of: Time.current,
      confidence_tenths: clamp_confidence(attrs.value(:confidence_tenths)),
      additional_attributes: sanitize_attrs(attrs.value(:additional_attributes))
    )
    detail.technology_types = types
    technology.update!(current_detail: detail)

    { technology_id: technology.id, detail_id: detail.id, created: created,
      type_errors: unknown_type_notes("technology type", unknown) }
  rescue ActiveRecord::RecordInvalid => e
    { error: e.message }
  end

  def find_or_create_technology(name)
    existing = Technology.joins(:current_detail)
                    .where("LOWER(technology_details.name) = ?", name.downcase)
                    .first

    return [ existing, false ] if existing

    [ Technology.create!, true ]
  end
end
