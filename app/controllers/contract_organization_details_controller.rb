class ContractOrganizationDetailsController < ApplicationController
  def show
    @detail = ContractOrganizationDetail.find(params[:id])
    @edge   = @detail.contract_organization
    @contract = @edge.contract
    @organization = @edge.organization
    @is_current = @edge.current_detail_id == @detail.id
  end
end
