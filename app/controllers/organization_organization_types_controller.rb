class OrganizationOrganizationTypesController < ApplicationController
  def index
    @organization_organization_types = OrganizationOrganizationType.order(:name)
  end

  def new
    @organization_organization_type = OrganizationOrganizationType.new
  end

  def create
    @organization_organization_type = OrganizationOrganizationType.new(organization_organization_type_params)

    if @organization_organization_type.save
      redirect_to organization_organization_types_path,
                  notice: "Organization ↔ Organization type \"#{@organization_organization_type.name}\" created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @organization_organization_type = OrganizationOrganizationType.find(params[:id])
  end

  def update
    @organization_organization_type = OrganizationOrganizationType.find(params[:id])

    if @organization_organization_type.update(organization_organization_type_params)
      redirect_to organization_organization_types_path,
                  notice: "Organization ↔ Organization type \"#{@organization_organization_type.name}\" updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def organization_organization_type_params
    permitted = params.require(:organization_organization_type).permit(:name, :description, :additional_attribute_keys)
    permitted[:additional_attribute_keys] =
      permitted[:additional_attribute_keys].to_s.split(",").map(&:strip).reject(&:blank?)
    permitted
  end
end
