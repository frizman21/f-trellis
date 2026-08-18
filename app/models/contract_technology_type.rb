class ContractTechnologyType < ApplicationRecord
  has_many :contract_technology_detail_contract_technology_types, dependent: :destroy
  has_many :contract_technology_details, through: :contract_technology_detail_contract_technology_types

  validates :name, presence: true, uniqueness: true
end
