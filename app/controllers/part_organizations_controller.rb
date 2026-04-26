class PartOrganizationsController < ApplicationController
  def show
    @part_organization = PartOrganization.find(params[:id])
    @part         = @part_organization.part
    @organization = @part_organization.organization
    @current      = @part_organization.current_detail
    @details      = @part_organization.part_organization_details
                       .includes(:part_organization_types, source_processing_report: :source)
                       .order(as_of: :desc, created_at: :desc)
  end
end
