class UpsertOrganizationTool < RubyLLM::Tool
  description <<~DESC
    Find an existing Organization by name — matched case-insensitively on the
    current detail — or create a new one. Always inserts a new
    OrganizationDetail attached to the active SourceProcessingReport, updating
    the Organization's current detail pointer. Returns the organization_id,
    the new detail_id, and whether the Organization was newly created.
  DESC

  param :name, type: "string", desc: "The organization's name as written on the source."
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

  def execute(name:, confidence_tenths: 800, additional_attributes: {})
    canonical = name.to_s.strip
    return { error: "name is required" } if canonical.empty?

    organization, created = find_or_create_organization(canonical)

    detail = OrganizationDetail.create!(
      organization: organization,
      source_processing_report: @report,
      name: canonical,
      as_of: Time.current,
      confidence_tenths: clamp_confidence(confidence_tenths),
      additional_attributes: sanitize_attrs(additional_attributes)
    )

    organization.update!(current_detail: detail)

    { organization_id: organization.id, detail_id: detail.id, created: created }
  rescue ActiveRecord::RecordInvalid => e
    { error: e.message }
  end

  private

  def find_or_create_organization(name)
    existing = Organization.joins(:current_detail).where(
      "LOWER(organization_details.name) = ?", name.downcase
    ).first

    return [ existing, false ] if existing

    [ Organization.create!, true ]
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
