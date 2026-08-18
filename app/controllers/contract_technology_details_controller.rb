class ContractTechnologyDetailsController < ApplicationController
  def show
    @detail = ContractTechnologyDetail.find(params[:id])
    @edge   = @detail.contract_technology
    @contract = @edge.contract
    @technology = @edge.technology
    @is_current = @edge.current_detail_id == @detail.id
  end
end
