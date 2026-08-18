class ScienceTechnologyTypesController < ApplicationController
  def index
    @science_technology_types = ScienceTechnologyType.order(:name)
  end

  def new
    @science_technology_type = ScienceTechnologyType.new
  end

  def create
    @science_technology_type = ScienceTechnologyType.new(science_technology_type_params)
    if @science_technology_type.save
      redirect_to science_technology_types_path, notice: "Science ↔ Technology type \"#{@science_technology_type.name}\" created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @science_technology_type = ScienceTechnologyType.find(params[:id])
  end

  def update
    @science_technology_type = ScienceTechnologyType.find(params[:id])
    if @science_technology_type.update(science_technology_type_params)
      redirect_to science_technology_types_path, notice: "Science ↔ Technology type \"#{@science_technology_type.name}\" updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def science_technology_type_params
    permitted = params.require(:science_technology_type).permit(:name, :description, :additional_attribute_keys)
    permitted[:additional_attribute_keys] =
      permitted[:additional_attribute_keys].to_s.split(",").map(&:strip).reject(&:blank?)
    permitted
  end
end
