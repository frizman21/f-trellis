class ContractPersonDetailsController < ApplicationController
  def show
    @detail = ContractPersonDetail.find(params[:id])
    @edge   = @detail.contract_person
    @contract = @edge.contract
    @person = @edge.person
    @is_current = @edge.current_detail_id == @detail.id
  end
end
