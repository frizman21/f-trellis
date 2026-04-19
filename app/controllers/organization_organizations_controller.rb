class OrganizationOrganizationsController < ApplicationController
  def show
    @organization_organization = OrganizationOrganization.find(params[:id])
    @organization_a = @organization_organization.organization_a
    @organization_b = @organization_organization.organization_b
    @current  = @organization_organization.current_detail
    @prior    = @organization_organization.organization_organization_details
                  .where.not(id: @current&.id)
                  .order(as_of: :desc)
  end
end
