class PersonOrganizationDetailsController < ApplicationController
  def show
    @detail = PersonOrganizationDetail.find(params[:id])
    @edge   = @detail.person_organization
    @person = @edge.person
    @organization = @edge.organization
    @is_current = @edge.current_detail_id == @detail.id
  end
end
