class LinkSubsidiaryTool < RubyLLM::Tool
  description <<~DESC
    Link two Organizations with the "Subsidiary" relationship type, marking
    one as the parent and the other as the subsidiary. Creates the
    OrganizationOrganization edge if one doesn't already exist, then inserts
    a new OrganizationOrganizationDetail attached to the active
    SourceProcessingReport, attaches the "Subsidiary" type, and updates the
    edge's current detail pointer. Use after upsert_organization to record
    that the parent acquired or owns the subsidiary.
  DESC

  param :parent_organization_id, type: "integer",
        desc: "Organization.id of the parent / acquirer from upsert_organization."
  param :subsidiary_organization_id, type: "integer",
        desc: "Organization.id of the subsidiary / target from upsert_organization."
  param :as_of, type: "string",
        desc: "ISO 8601 datetime the subsidiary relationship became effective. Defaults to now.",
        required: false
  param :confidence_tenths, type: "integer",
        desc: "Confidence 0–1000 (1000 = 100%). Defaults to 800.",
        required: false
  param :additional_attributes, type: "object",
        desc: "Flat map of string keys to scalar values (e.g. announcement_date, close_date, deal_value, currency, payment_form, status, source_url).",
        required: false

  SUBSIDIARY_TYPE_NAME = "Subsidiary".freeze

  def initialize(report)
    super()
    @report = report
  end

  def execute(parent_organization_id:, subsidiary_organization_id:, as_of: nil, confidence_tenths: 800, additional_attributes: {})
    if parent_organization_id == subsidiary_organization_id
      return { error: "parent and subsidiary must be different organizations" }
    end

    parent = Organization.find_by(id: parent_organization_id)
    return { error: "no organization ##{parent_organization_id}" } unless parent

    subsidiary = Organization.find_by(id: subsidiary_organization_id)
    return { error: "no organization ##{subsidiary_organization_id}" } unless subsidiary

    subsidiary_type = OrganizationOrganizationType.find_by(name: SUBSIDIARY_TYPE_NAME)
    return { error: "OrganizationOrganizationType '#{SUBSIDIARY_TYPE_NAME}' is not configured" } unless subsidiary_type

    a_id, b_id = [ parent.id, subsidiary.id ].sort
    oo = OrganizationOrganization.find_or_create_by!(organization_a_id: a_id, organization_b_id: b_id)

    attrs = sanitize_attrs(additional_attributes).merge(
      "parent_organization_id" => parent.id,
      "subsidiary_organization_id" => subsidiary.id
    )

    detail = OrganizationOrganizationDetail.create!(
      organization_organization: oo,
      source_processing_report: @report,
      as_of: parse_as_of(as_of),
      confidence_tenths: clamp_confidence(confidence_tenths),
      additional_attributes: attrs
    )

    detail.organization_organization_types = [ subsidiary_type ]
    oo.update!(current_detail: detail)

    {
      organization_organization_id: oo.id,
      detail_id: detail.id,
      parent_organization_id: parent.id,
      subsidiary_organization_id: subsidiary.id
    }
  rescue ActiveRecord::RecordInvalid => e
    { error: e.message }
  end

  private

  def parse_as_of(value)
    return Time.current if value.blank?

    Time.zone.parse(value.to_s) || Time.current
  rescue ArgumentError
    Time.current
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
