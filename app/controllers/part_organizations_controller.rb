class PartOrganizationsController < ApplicationController
  def show
    @part_organization = PartOrganization.find(params[:id])
    @part         = @part_organization.part
    @organization = @part_organization.organization
    @current      = @part_organization.current_detail
    @prior        = @part_organization.part_organization_details
                       .where.not(id: @current&.id)
                       .order(as_of: :desc)
  end
end
