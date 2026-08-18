class ContractPartDetailsController < ApplicationController
  def show
    @detail = ContractPartDetail.find(params[:id])
    @edge   = @detail.contract_part
    @contract = @edge.contract
    @part = @edge.part
    @is_current = @edge.current_detail_id == @detail.id
  end
end
