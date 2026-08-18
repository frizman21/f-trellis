class ContractOrganization < ApplicationRecord
  belongs_to :contract
  belongs_to :organization
  belongs_to :current_detail, class_name: "ContractOrganizationDetail", optional: true
  has_many :contract_organization_details, dependent: :destroy
end
