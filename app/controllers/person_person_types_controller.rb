class PersonPersonTypesController < ApplicationController
  def index
    @person_person_types = PersonPersonType.order(:name)
  end

  def new
    @person_person_type = PersonPersonType.new
  end

  def create
    @person_person_type = PersonPersonType.new(person_person_type_params)

    if @person_person_type.save
      redirect_to person_person_types_path,
                  notice: "Person ↔ Person type \"#{@person_person_type.name}\" created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @person_person_type = PersonPersonType.find(params[:id])
  end

  def update
    @person_person_type = PersonPersonType.find(params[:id])

    if @person_person_type.update(person_person_type_params)
      redirect_to person_person_types_path,
                  notice: "Person ↔ Person type \"#{@person_person_type.name}\" updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def person_person_type_params
    permitted = params.require(:person_person_type).permit(:name, :description, :additional_attribute_keys)
    permitted[:additional_attribute_keys] =
      permitted[:additional_attribute_keys].to_s.split(",").map(&:strip).reject(&:blank?)
    permitted
  end
end
