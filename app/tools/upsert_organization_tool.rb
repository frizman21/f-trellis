class UpsertOrganizationTool < RubyLLM::Tool
  include EntityUpsert

  description <<~DESC
    Record every Organization found on the page in ONE call — pass them all in
    the organizations array rather than calling this tool repeatedly.

    For each entry: find an existing Organization by name — matched
    case-insensitively on the current detail — or create a new one. Always
    inserts a new OrganizationDetail attached to the active
    SourceProcessingReport, updating the Organization's current detail pointer.
    Pass the acronym whenever the source states one or you know it.

    Returns a results array, in the same order as the input, each entry giving
    the organization_id, the new detail_id, and whether the Organization was
    newly created. An entry that could not be recorded returns an error in its
    slot; the remaining entries are still recorded.
  DESC

  params do
    array :organizations, description: "Every organization found on the page." do
      object do
        string :name, description: "The organization's name as written on the source."
        string :acronym,
               description: "The organization's acronym or initialism, e.g. NASA. Omit if unknown.",
               required: false
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

  def execute(organizations:)
    entries = Array(organizations)
    return { error: "organizations must be a non-empty array" } if entries.empty?

    { results: entries.map { |entry| upsert_one(entry) } }
  end

  private

  def upsert_one(entry)
    attrs = EntityUpsert::Entry.new(entry)
    canonical = attrs.string(:name)
    return { error: "name is required" } if canonical.empty?

    organization, created = find_or_create_organization(canonical)

    detail = OrganizationDetail.create!(
      organization: organization,
      source_processing_report: @report,
      name: canonical,
      acronym: attrs.string(:acronym).presence,
      as_of: Time.current,
      confidence_tenths: clamp_confidence(attrs.value(:confidence_tenths)),
      additional_attributes: sanitize_attrs(attrs.value(:additional_attributes))
    )

    organization.update!(current_detail: detail)

    { organization_id: organization.id, detail_id: detail.id, created: created }
  rescue ActiveRecord::RecordInvalid => e
    { error: e.message }
  end

  def find_or_create_organization(name)
    existing = Organization.joins(:current_detail).where(
      "LOWER(organization_details.name) = ?", name.downcase
    ).first

    return [ existing, false ] if existing

    [ Organization.create!, true ]
  end
end
