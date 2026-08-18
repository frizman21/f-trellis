class ContractOrganizationDetail < ApplicationRecord
  belongs_to :contract_organization
  belongs_to :source_processing_report
  has_many :contract_organization_detail_contract_organization_types, dependent: :destroy
  has_many :contract_organization_types, through: :contract_organization_detail_contract_organization_types
end
