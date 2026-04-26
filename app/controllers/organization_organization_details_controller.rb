class OrganizationOrganizationDetailsController < ApplicationController
  def show
    @detail = OrganizationOrganizationDetail.find(params[:id])
    @edge   = @detail.organization_organization
    @organization_a = @edge.organization_a
    @organization_b = @edge.organization_b
    @is_current = @edge.current_detail_id == @detail.id
  end
end
