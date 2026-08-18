class OrganizationTechnologiesController < ApplicationController
  def show
    @organization_technology = OrganizationTechnology.find(params[:id])
    @organization = @organization_technology.organization
    @technology = @organization_technology.technology
    @current = @organization_technology.current_detail
    @details = @organization_technology.organization_technology_details
                 .includes(:organization_technology_types, source_processing_report: :source)
                 .order(as_of: :desc, created_at: :desc)
  end
end
