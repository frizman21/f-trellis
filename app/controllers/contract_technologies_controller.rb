class ContractTechnologiesController < ApplicationController
  def show
    @contract_technology = ContractTechnology.find(params[:id])
    @contract = @contract_technology.contract
    @technology = @contract_technology.technology
    @current = @contract_technology.current_detail
    @details = @contract_technology.contract_technology_details
                 .includes(:contract_technology_types, source_processing_report: :source)
                 .order(as_of: :desc, created_at: :desc)
  end
end
