class ContractOrganizationsController < ApplicationController
  def show
    @contract_organization = ContractOrganization.find(params[:id])
    @contract = @contract_organization.contract
    @organization = @contract_organization.organization
    @current = @contract_organization.current_detail
    @details = @contract_organization.contract_organization_details
                 .includes(:contract_organization_types, source_processing_report: :source)
                 .order(as_of: :desc, created_at: :desc)
  end
end
