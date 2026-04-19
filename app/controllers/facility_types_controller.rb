class FacilityTypesController < ApplicationController
  def index
    @facility_types = FacilityType.order(:name)
  end
end
