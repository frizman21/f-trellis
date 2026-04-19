class PersonOrganizationTypesController < ApplicationController
  def index
    @person_organization_types = PersonOrganizationType.order(:name)
  end

  def new
    @person_organization_type = PersonOrganizationType.new
  end

  def create
    @person_organization_type = PersonOrganizationType.new(person_organization_type_params)

    if @person_organization_type.save
      redirect_to person_organization_types_path,
                  notice: "Relationship type \"#{@person_organization_type.name}\" created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @person_organization_type = PersonOrganizationType.find(params[:id])
  end

  def update
    @person_organization_type = PersonOrganizationType.find(params[:id])

    if @person_organization_type.update(person_organization_type_params)
      redirect_to person_organization_types_path,
                  notice: "Relationship type \"#{@person_organization_type.name}\" updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def person_organization_type_params
    permitted = params.require(:person_organization_type).permit(:name, :description, :additional_attribute_keys)
    permitted[:additional_attribute_keys] =
      permitted[:additional_attribute_keys].to_s.split(",").map(&:strip).reject(&:blank?)
    permitted
  end
end
