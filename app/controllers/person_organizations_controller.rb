class PersonOrganizationsController < ApplicationController
  def show
    @person_organization = PersonOrganization.find(params[:id])
    @person       = @person_organization.person
    @organization = @person_organization.organization
    @current      = @person_organization.current_detail
    @prior        = @person_organization.person_organization_details
                       .where.not(id: @current&.id)
                       .order(as_of: :desc)
  end
end
