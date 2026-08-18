class OrganizationTechnologyDetailsController < ApplicationController
  def show
    @detail = OrganizationTechnologyDetail.find(params[:id])
    @edge   = @detail.organization_technology
    @organization = @edge.organization
    @technology = @edge.technology
    @is_current = @edge.current_detail_id == @detail.id
  end
end
