class TechnologyTypesController < ApplicationController
  def index
    @technology_types = TechnologyType.order(:name)
  end

  def new
    @technology_type = TechnologyType.new
  end

  def create
    @technology_type = TechnologyType.new(technology_type_params)
    if @technology_type.save
      redirect_to technology_types_path, notice: "Technology type \"#{@technology_type.name}\" created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @technology_type = TechnologyType.find(params[:id])
  end

  def update
    @technology_type = TechnologyType.find(params[:id])
    if @technology_type.update(technology_type_params)
      redirect_to technology_types_path, notice: "Technology type \"#{@technology_type.name}\" updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def technology_type_params
    permitted = params.require(:technology_type).permit(:name, :description, :additional_attribute_keys)
    permitted[:additional_attribute_keys] =
      permitted[:additional_attribute_keys].to_s.split(",").map(&:strip).reject(&:blank?)
    permitted
  end
end
