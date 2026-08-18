class ContractPartTypesController < ApplicationController
  def index
    @contract_part_types = ContractPartType.order(:name)
  end

  def new
    @contract_part_type = ContractPartType.new
  end

  def create
    @contract_part_type = ContractPartType.new(contract_part_type_params)
    if @contract_part_type.save
      redirect_to contract_part_types_path, notice: "Contract ↔ Part type \"#{@contract_part_type.name}\" created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @contract_part_type = ContractPartType.find(params[:id])
  end

  def update
    @contract_part_type = ContractPartType.find(params[:id])
    if @contract_part_type.update(contract_part_type_params)
      redirect_to contract_part_types_path, notice: "Contract ↔ Part type \"#{@contract_part_type.name}\" updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def contract_part_type_params
    permitted = params.require(:contract_part_type).permit(:name, :description, :additional_attribute_keys)
    permitted[:additional_attribute_keys] =
      permitted[:additional_attribute_keys].to_s.split(",").map(&:strip).reject(&:blank?)
    permitted
  end
end
