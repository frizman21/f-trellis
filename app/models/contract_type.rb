class ContractType < ApplicationRecord
  has_many :contract_detail_contract_types, dependent: :destroy
  has_many :contract_details, through: :contract_detail_contract_types

  validates :name, presence: true, uniqueness: true
end
