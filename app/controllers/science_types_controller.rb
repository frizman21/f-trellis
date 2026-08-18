class ScienceTypesController < ApplicationController
  def index
    @science_types = ScienceType.order(:name)
  end

  def new
    @science_type = ScienceType.new
  end

  def create
    @science_type = ScienceType.new(science_type_params)
    if @science_type.save
      redirect_to science_types_path, notice: "Science type \"#{@science_type.name}\" created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @science_type = ScienceType.find(params[:id])
  end

  def update
    @science_type = ScienceType.find(params[:id])
    if @science_type.update(science_type_params)
      redirect_to science_types_path, notice: "Science type \"#{@science_type.name}\" updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def science_type_params
    permitted = params.require(:science_type).permit(:name, :description, :additional_attribute_keys)
    permitted[:additional_attribute_keys] =
      permitted[:additional_attribute_keys].to_s.split(",").map(&:strip).reject(&:blank?)
    permitted
  end
end
