class PersonOrganizationsController < ApplicationController
  def show
    @person_organization = PersonOrganization.find(params[:id])
    @person       = @person_organization.person
    @organization = @person_organization.organization
    @current      = @person_organization.current_detail
    @details      = @person_organization.person_organization_details
                       .includes(:person_organization_types, source_processing_report: :source)
                       .order(as_of: :desc, created_at: :desc)
  end
end
