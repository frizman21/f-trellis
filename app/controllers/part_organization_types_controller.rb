class PartOrganizationTypesController < ApplicationController
  def index
    @part_organization_types = PartOrganizationType.order(:name)
  end

  def new
    @part_organization_type = PartOrganizationType.new
  end

  def create
    @part_organization_type = PartOrganizationType.new(part_organization_type_params)
    if @part_organization_type.save
      redirect_to part_organization_types_path, notice: "Part ↔ Organization type \"#{@part_organization_type.name}\" created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @part_organization_type = PartOrganizationType.find(params[:id])
  end

  def update
    @part_organization_type = PartOrganizationType.find(params[:id])
    if @part_organization_type.update(part_organization_type_params)
      redirect_to part_organization_types_path, notice: "Part ↔ Organization type \"#{@part_organization_type.name}\" updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def part_organization_type_params
    permitted = params.require(:part_organization_type).permit(:name, :description, :additional_attribute_keys)
    permitted[:additional_attribute_keys] =
      permitted[:additional_attribute_keys].to_s.split(",").map(&:strip).reject(&:blank?)
    permitted
  end
end
