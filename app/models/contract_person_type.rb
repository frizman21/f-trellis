class ContractPersonType < ApplicationRecord
  has_many :contract_person_detail_contract_person_types, dependent: :destroy
  has_many :contract_person_details, through: :contract_person_detail_contract_person_types

  validates :name, presence: true, uniqueness: true
end
