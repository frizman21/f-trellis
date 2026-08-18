class PersonScienceTypesController < ApplicationController
  def index
    @person_science_types = PersonScienceType.order(:name)
  end

  def new
    @person_science_type = PersonScienceType.new
  end

  def create
    @person_science_type = PersonScienceType.new(person_science_type_params)
    if @person_science_type.save
      redirect_to person_science_types_path, notice: "Person ↔ Science type \"#{@person_science_type.name}\" created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @person_science_type = PersonScienceType.find(params[:id])
  end

  def update
    @person_science_type = PersonScienceType.find(params[:id])
    if @person_science_type.update(person_science_type_params)
      redirect_to person_science_types_path, notice: "Person ↔ Science type \"#{@person_science_type.name}\" updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def person_science_type_params
    permitted = params.require(:person_science_type).permit(:name, :description, :additional_attribute_keys)
    permitted[:additional_attribute_keys] =
      permitted[:additional_attribute_keys].to_s.split(",").map(&:strip).reject(&:blank?)
    permitted
  end
end
