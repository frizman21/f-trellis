class UpsertPersonTool < RubyLLM::Tool
  include EntityUpsert

  description <<~DESC
    Record every Person found on the page in ONE call — pass them all in the
    people array rather than calling this tool repeatedly.

    For each entry: find an existing Person by (first_name, last_name) — matched
    case-insensitively on the current detail — or create a new one. Always
    inserts a new PersonDetail attached to the active SourceProcessingReport,
    updating the Person's current detail pointer.

    Returns a results array, in the same order as the input, each entry giving
    the person_id, the new detail_id, and whether the Person was newly created.
    An entry that could not be recorded returns an error in its slot; the
    remaining entries are still recorded.
  DESC

  params do
    array :people, description: "Every person found on the page." do
      object do
        string :first_name, description: "The person's given name."
        string :last_name, description: "The person's family name."
        integer :confidence_tenths,
                description: "Confidence 0–1000 (1000 = 100%). Defaults to 800.",
                required: false
        array :additional_attributes,
              description: "Extra detail fields as key/value pairs. Omit if there are none.",
              required: false do
          object do
            string :key, description: "Field name."
            string :value, description: "Field value."
          end
        end
      end
    end
  end

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
