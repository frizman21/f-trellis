# `link_organization_organization` as an evaluation runs it: identical contract,
# no rows written. See RecordingLinkPersonOrganizationTool for why the writing
# tool's rejections are reproduced rather than waved through.
class RecordingLinkOrganizationOrganizationTool < RubyLLM::Tool
  include LinkOrganizationOrganizationContract

  def initialize(recorder)
    super()
    @recorder = recorder
  end

  def execute(organization_a_id:, organization_b_id:, type:, as_of: nil, confidence_tenths: 800,
              additional_attributes: {})
    if organization_a_id == organization_b_id
      return { error: "organization_a_id and organization_b_id must be different" }
    end

    return { error: "no organization ##{organization_a_id}" } unless @recorder.label_for(:organization, organization_a_id)
    return { error: "no organization ##{organization_b_id}" } unless @recorder.label_for(:organization, organization_b_id)

    type_name = type.to_s.strip
    return { error: "type is required" } if type_name.empty?

    relationship_type = OrganizationOrganizationType.find_by(name: type_name)
    return { error: "OrganizationOrganizationType '#{type_name}' is not configured" } unless relationship_type

    edge_id = @recorder.record_organization_organization(
      organization_a_id: organization_a_id, organization_b_id: organization_b_id,
      relationship_type: relationship_type.name, attributes: additional_attributes
    )

    {
      organization_organization_id: edge_id,
      detail_id: @recorder.next_detail_id,
      organization_a_id: organization_a_id,
      organization_b_id: organization_b_id,
      type: relationship_type.name
    }
  end
end
