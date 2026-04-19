class OrganizationTypesController < ApplicationController
  def index
    @organization_types = OrganizationType.order(:name)
  end

  def new
    @organization_type = OrganizationType.new
  end

  def create
    @organization_type = OrganizationType.new(organization_type_params)

    if @organization_type.save
      redirect_to organization_types_path, notice: "Organization type \"#{@organization_type.name}\" created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @organization_type = OrganizationType.find(params[:id])
  end

  def update
    @organization_type = OrganizationType.find(params[:id])

    if @organization_type.update(organization_type_params)
      redirect_to organization_types_path, notice: "Organization type \"#{@organization_type.name}\" updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def organization_type_params
    permitted = params.require(:organization_type).permit(:name, :description, :additional_attribute_keys)
    permitted[:additional_attribute_keys] =
      permitted[:additional_attribute_keys].to_s.split(",").map(&:strip).reject(&:blank?)
    permitted
  end
end
