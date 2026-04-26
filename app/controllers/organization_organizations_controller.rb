class OrganizationOrganizationsController < ApplicationController
  def show
    @organization_organization = OrganizationOrganization.find(params[:id])
    @organization_a = @organization_organization.organization_a
    @organization_b = @organization_organization.organization_b
    @current  = @organization_organization.current_detail
    @details  = @organization_organization.organization_organization_details
                  .includes(:organization_organization_types, source_processing_report: :source)
                  .order(as_of: :desc, created_at: :desc)
  end
end
