class ContractTechnologyTypesController < ApplicationController
  def index
    @contract_technology_types = ContractTechnologyType.order(:name)
  end

  def new
    @contract_technology_type = ContractTechnologyType.new
  end

  def create
    @contract_technology_type = ContractTechnologyType.new(contract_technology_type_params)
    if @contract_technology_type.save
      redirect_to contract_technology_types_path, notice: "Contract ↔ Technology type \"#{@contract_technology_type.name}\" created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @contract_technology_type = ContractTechnologyType.find(params[:id])
  end

  def update
    @contract_technology_type = ContractTechnologyType.find(params[:id])
    if @contract_technology_type.update(contract_technology_type_params)
      redirect_to contract_technology_types_path, notice: "Contract ↔ Technology type \"#{@contract_technology_type.name}\" updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def contract_technology_type_params
    permitted = params.require(:contract_technology_type).permit(:name, :description, :additional_attribute_keys)
    permitted[:additional_attribute_keys] =
      permitted[:additional_attribute_keys].to_s.split(",").map(&:strip).reject(&:blank?)
    permitted
  end
end
