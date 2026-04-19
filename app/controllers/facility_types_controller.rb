class FacilityTypesController < ApplicationController
  def index
    @facility_types = FacilityType.order(:name)
  end

  def new
    @facility_type = FacilityType.new
  end

  def create
    @facility_type = FacilityType.new(facility_type_params)

    if @facility_type.save
      redirect_to facility_types_path, notice: "Facility type \"#{@facility_type.name}\" created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @facility_type = FacilityType.find(params[:id])
  end

  def update
    @facility_type = FacilityType.find(params[:id])

    if @facility_type.update(facility_type_params)
      redirect_to facility_types_path, notice: "Facility type \"#{@facility_type.name}\" updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def facility_type_params
    permitted = params.require(:facility_type).permit(:name, :description, :additional_attribute_keys)
    permitted[:additional_attribute_keys] =
      permitted[:additional_attribute_keys].to_s.split(",").map(&:strip).reject(&:blank?)
    permitted
  end
end
