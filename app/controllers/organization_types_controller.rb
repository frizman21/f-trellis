class OrganizationTypesController < ApplicationController
  def index
    @organization_types = OrganizationType.order(:name)
  end
end
