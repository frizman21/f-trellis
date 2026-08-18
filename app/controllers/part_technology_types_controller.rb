class PartTechnologyTypesController < ApplicationController
  def index
    @part_technology_types = PartTechnologyType.order(:name)
  end

  def new
    @part_technology_type = PartTechnologyType.new
  end

  def create
    @part_technology_type = PartTechnologyType.new(part_technology_type_params)
    if @part_technology_type.save
      redirect_to part_technology_types_path, notice: "Part ↔ Technology type \"#{@part_technology_type.name}\" created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @part_technology_type = PartTechnologyType.find(params[:id])
  end

  def update
    @part_technology_type = PartTechnologyType.find(params[:id])
    if @part_technology_type.update(part_technology_type_params)
      redirect_to part_technology_types_path, notice: "Part ↔ Technology type \"#{@part_technology_type.name}\" updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def part_technology_type_params
    permitted = params.require(:part_technology_type).permit(:name, :description, :additional_attribute_keys)
    permitted[:additional_attribute_keys] =
      permitted[:additional_attribute_keys].to_s.split(",").map(&:strip).reject(&:blank?)
    permitted
  end
end
