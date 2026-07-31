class LinkOrganizationOrganizationTool < RubyLLM::Tool
  include LinkOrganizationOrganizationContract

  def initialize(report)
    super()
    @report = report
  end

  def execute(organization_a_id:, organization_b_id:, type:, as_of: nil, confidence_tenths: 800, additional_attributes: {})
    if organization_a_id == organization_b_id
      return { error: "organization_a_id and organization_b_id must be different" }
    end

    org_a = Organization.find_by(id: organization_a_id)
    return { error: "no organization ##{organization_a_id}" } unless org_a

    org_b = Organization.find_by(id: organization_b_id)
    return { error: "no organization ##{organization_b_id}" } unless org_b

    type_name = type.to_s.strip
    return { error: "type is required" } if type_name.empty?

    relationship_type = OrganizationOrganizationType.find_by(name: type_name)
    return { error: "OrganizationOrganizationType '#{type_name}' is not configured" } unless relationship_type

    sorted_a, sorted_b = [ org_a.id, org_b.id ].sort
    edge = OrganizationOrganization.find_or_create_by!(
      organization_a_id: sorted_a, organization_b_id: sorted_b
    )

    detail = OrganizationOrganizationDetail.create!(
      organization_organization: edge,
      source_processing_report: @report,
      as_of: parse_as_of(as_of),
      confidence_tenths: clamp_confidence(confidence_tenths),
      additional_attributes: sanitize_attrs(additional_attributes)
    )

    detail.organization_organization_types = [ relationship_type ]
    edge.update!(current_detail: detail)

    {
      organization_organization_id: edge.id,
      detail_id: detail.id,
      organization_a_id: edge.organization_a_id,
      organization_b_id: edge.organization_b_id,
      type: relationship_type.name
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
