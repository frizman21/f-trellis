class ContractOrganizationTypesController < ApplicationController
  def index
    @contract_organization_types = ContractOrganizationType.order(:name)
  end

  def new
    @contract_organization_type = ContractOrganizationType.new
  end

  def create
    @contract_organization_type = ContractOrganizationType.new(contract_organization_type_params)
    if @contract_organization_type.save
      redirect_to contract_organization_types_path, notice: "Contract ↔ Organization type \"#{@contract_organization_type.name}\" created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @contract_organization_type = ContractOrganizationType.find(params[:id])
  end

  def update
    @contract_organization_type = ContractOrganizationType.find(params[:id])
    if @contract_organization_type.update(contract_organization_type_params)
      redirect_to contract_organization_types_path, notice: "Contract ↔ Organization type \"#{@contract_organization_type.name}\" updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def contract_organization_type_params
    permitted = params.require(:contract_organization_type).permit(:name, :description, :additional_attribute_keys)
    permitted[:additional_attribute_keys] =
      permitted[:additional_attribute_keys].to_s.split(",").map(&:strip).reject(&:blank?)
    permitted
  end
end
