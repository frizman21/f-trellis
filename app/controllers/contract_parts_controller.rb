class ContractPartsController < ApplicationController
  def show
    @contract_part = ContractPart.find(params[:id])
    @contract = @contract_part.contract
    @part = @contract_part.part
    @current = @contract_part.current_detail
    @details = @contract_part.contract_part_details
                 .includes(:contract_part_types, source_processing_report: :source)
                 .order(as_of: :desc, created_at: :desc)
  end
end
