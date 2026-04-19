class PartPartTypesController < ApplicationController
  def index
    @part_part_types = PartPartType.order(:name)
  end

  def new
    @part_part_type = PartPartType.new
  end

  def create
    @part_part_type = PartPartType.new(part_part_type_params)
    if @part_part_type.save
      redirect_to part_part_types_path, notice: "Part ↔ Part type \"#{@part_part_type.name}\" created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @part_part_type = PartPartType.find(params[:id])
  end

  def update
    @part_part_type = PartPartType.find(params[:id])
    if @part_part_type.update(part_part_type_params)
      redirect_to part_part_types_path, notice: "Part ↔ Part type \"#{@part_part_type.name}\" updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def part_part_type_params
    permitted = params.require(:part_part_type).permit(:name, :description, :additional_attribute_keys)
    permitted[:additional_attribute_keys] =
      permitted[:additional_attribute_keys].to_s.split(",").map(&:strip).reject(&:blank?)
    permitted
  end
end
