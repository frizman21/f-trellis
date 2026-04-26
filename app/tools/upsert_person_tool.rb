class UpsertPersonTool < RubyLLM::Tool
  description <<~DESC
    Find an existing Person by (first_name, last_name) — matched case-insensitively
    on the current detail — or create a new one. Always inserts a new PersonDetail
    attached to the active SourceProcessingReport, updating the Person's current
    detail pointer. Returns the person_id, the new detail_id, and whether the
    Person was newly created.
  DESC

  param :first_name, type: "string", desc: "The person's given name."
  param :last_name,  type: "string", desc: "The person's family name."
  param :confidence_tenths, type: "integer",
        desc: "Confidence 0–1000 (1000 = 100%). Defaults to 800.",
        required: false
  param :additional_attributes, type: "object",
        desc: "Flat map of string keys to scalar values for extra detail fields.",
        required: false

  def initialize(report)
    super()
    @report = report
  end

  def execute(first_name:, last_name:, confidence_tenths: 800, additional_attributes: {})
    first = first_name.to_s.strip
    last  = last_name.to_s.strip
    return { error: "first_name and last_name are required" } if first.empty? || last.empty?

    person, created = find_or_create_person(first, last)

    detail = PersonDetail.create!(
      person: person,
      source_processing_report: @report,
      first_name: first,
      last_name: last,
      as_of: Time.current,
      confidence_tenths: clamp_confidence(confidence_tenths),
      additional_attributes: sanitize_attrs(additional_attributes)
    )

    person.update!(current_detail: detail)

    { person_id: person.id, detail_id: detail.id, created: created }
  rescue ActiveRecord::RecordInvalid => e
    { error: e.message }
  end

  private

  def find_or_create_person(first, last)
    existing = Person.joins(:current_detail).where(
      "LOWER(person_details.first_name) = ? AND LOWER(person_details.last_name) = ?",
      first.downcase, last.downcase
    ).first

    return [ existing, false ] if existing

    [ Person.create!, true ]
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
