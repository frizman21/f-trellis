class ContractPartType < ApplicationRecord
  has_many :contract_part_detail_contract_part_types, dependent: :destroy
  has_many :contract_part_details, through: :contract_part_detail_contract_part_types

  validates :name, presence: true, uniqueness: true
end
