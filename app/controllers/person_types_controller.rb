class PersonTypesController < ApplicationController
  def index
    @person_types = PersonType.order(:name)
  end

  def new
    @person_type = PersonType.new
  end

  def create
    @person_type = PersonType.new(person_type_params)

    if @person_type.save
      redirect_to person_types_path, notice: "Person type \"#{@person_type.name}\" created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @person_type = PersonType.find(params[:id])
  end

  def update
    @person_type = PersonType.find(params[:id])

    if @person_type.update(person_type_params)
      redirect_to person_types_path, notice: "Person type \"#{@person_type.name}\" updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def person_type_params
    permitted = params.require(:person_type).permit(:name, :description, :additional_attribute_keys)
    permitted[:additional_attribute_keys] =
      permitted[:additional_attribute_keys].to_s.split(",").map(&:strip).reject(&:blank?)
    permitted
  end
end
