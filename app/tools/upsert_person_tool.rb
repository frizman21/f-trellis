class UpsertPersonTool < RubyLLM::Tool
  include EntityUpsert
  include UpsertPersonContract

  def initialize(report)
    super()
    @report = report
  end

  def execute(people:)
    entries = Array(people)
    return { error: "people must be a non-empty array" } if entries.empty?

    { results: entries.map { |entry| upsert_one(entry) } }
  end

  private

  def upsert_one(entry)
    attrs = EntityUpsert::Entry.new(entry)
    first = attrs.string(:first_name)
    last  = attrs.string(:last_name)
    return { error: "first_name and last_name are required" } if first.empty? || last.empty?

    person, created = find_or_create_person(first, last)

    detail = PersonDetail.create!(
      person: person,
      source_processing_report: @report,
      first_name: first,
      last_name: last,
      as_of: Time.current,
      confidence_tenths: clamp_confidence(attrs.value(:confidence_tenths)),
      additional_attributes: sanitize_attrs(attrs.value(:additional_attributes))
    )

    person.update!(current_detail: detail)

    { person_id: person.id, detail_id: detail.id, created: created }
  rescue ActiveRecord::RecordInvalid => e
    { error: e.message }
  end

  def find_or_create_person(first, last)
    existing = Person.joins(:current_detail).where(
      "LOWER(person_details.first_name) = ? AND LOWER(person_details.last_name) = ?",
      first.downcase, last.downcase
    ).first

    return [ existing, false ] if existing

    [ Person.create!, true ]
  end
end
