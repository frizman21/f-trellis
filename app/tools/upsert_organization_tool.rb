class UpsertOrganizationTool < RubyLLM::Tool
  include EntityUpsert
  # Name, description and schema live in the contract, shared with the recording
  # stand-in an evaluation runs. Two copies would drift.
  include UpsertOrganizationContract

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
