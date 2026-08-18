class ContractTypesController < ApplicationController
  def index
    @contract_types = ContractType.order(:name)
  end

  def new
    @contract_type = ContractType.new
  end

  def create
    @contract_type = ContractType.new(contract_type_params)
    if @contract_type.save
      redirect_to contract_types_path, notice: "Contract type \"#{@contract_type.name}\" created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @contract_type = ContractType.find(params[:id])
  end

  def update
    @contract_type = ContractType.find(params[:id])
    if @contract_type.update(contract_type_params)
      redirect_to contract_types_path, notice: "Contract type \"#{@contract_type.name}\" updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def contract_type_params
    permitted = params.require(:contract_type).permit(:name, :description, :additional_attribute_keys)
    permitted[:additional_attribute_keys] =
      permitted[:additional_attribute_keys].to_s.split(",").map(&:strip).reject(&:blank?)
    permitted
  end
end
