class OrganizationTechnologyTypesController < ApplicationController
  def index
    @organization_technology_types = OrganizationTechnologyType.order(:name)
  end

  def new
    @organization_technology_type = OrganizationTechnologyType.new
  end

  def create
    @organization_technology_type = OrganizationTechnologyType.new(organization_technology_type_params)
    if @organization_technology_type.save
      redirect_to organization_technology_types_path, notice: "Organization ↔ Technology type \"#{@organization_technology_type.name}\" created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @organization_technology_type = OrganizationTechnologyType.find(params[:id])
  end

  def update
    @organization_technology_type = OrganizationTechnologyType.find(params[:id])
    if @organization_technology_type.update(organization_technology_type_params)
      redirect_to organization_technology_types_path, notice: "Organization ↔ Technology type \"#{@organization_technology_type.name}\" updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def organization_technology_type_params
    permitted = params.require(:organization_technology_type).permit(:name, :description, :additional_attribute_keys)
    permitted[:additional_attribute_keys] =
      permitted[:additional_attribute_keys].to_s.split(",").map(&:strip).reject(&:blank?)
    permitted
  end
end
