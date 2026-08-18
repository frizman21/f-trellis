class ContractPersonTypesController < ApplicationController
  def index
    @contract_person_types = ContractPersonType.order(:name)
  end

  def new
    @contract_person_type = ContractPersonType.new
  end

  def create
    @contract_person_type = ContractPersonType.new(contract_person_type_params)
    if @contract_person_type.save
      redirect_to contract_person_types_path, notice: "Contract ↔ Person type \"#{@contract_person_type.name}\" created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @contract_person_type = ContractPersonType.find(params[:id])
  end

  def update
    @contract_person_type = ContractPersonType.find(params[:id])
    if @contract_person_type.update(contract_person_type_params)
      redirect_to contract_person_types_path, notice: "Contract ↔ Person type \"#{@contract_person_type.name}\" updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def contract_person_type_params
    permitted = params.require(:contract_person_type).permit(:name, :description, :additional_attribute_keys)
    permitted[:additional_attribute_keys] =
      permitted[:additional_attribute_keys].to_s.split(",").map(&:strip).reject(&:blank?)
    permitted
  end
end
