class ContractOrganizationType < ApplicationRecord
  has_many :contract_organization_detail_contract_organization_types, dependent: :destroy
  has_many :contract_organization_details, through: :contract_organization_detail_contract_organization_types

  validates :name, presence: true, uniqueness: true
end
