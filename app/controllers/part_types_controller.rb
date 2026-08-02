class PartTypesController < ApplicationController
  def index
    @part_types = PartType.includes(:part_type_parameters).order(:name)
  end

  def new
    @part_type = PartType.new
    # One blank row so the form shows what a parameter is without a click.
    @part_type.part_type_parameters.build
  end

  def create
    @part_type = PartType.new(part_type_params)

    if @part_type.save
      redirect_to part_types_path, notice: "Part type \"#{@part_type.name}\" created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @part_type = PartType.find(params[:id])
    @part_type.part_type_parameters.build
  end

  def update
    @part_type = PartType.find(params[:id])

    if @part_type.update(part_type_params)
      redirect_to part_types_path, notice: "Part type \"#{@part_type.name}\" updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def part_type_params
    permitted = params.require(:part_type).permit(
      :name, :description, :additional_attribute_keys,
      part_type_parameters_attributes: [ :id, :name, :unit, :value_type, :description, :_destroy ]
    )
    permitted[:additional_attribute_keys] =
      permitted[:additional_attribute_keys].to_s.split(",").map(&:strip).reject(&:blank?)
    permitted
  end
end
