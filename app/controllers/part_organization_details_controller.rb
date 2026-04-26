class PartOrganizationDetailsController < ApplicationController
  def show
    @detail = PartOrganizationDetail.find(params[:id])
    @edge   = @detail.part_organization
    @part   = @edge.part
    @organization = @edge.organization
    @is_current = @edge.current_detail_id == @detail.id
  end
end
