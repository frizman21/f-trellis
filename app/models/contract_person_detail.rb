class ContractPersonDetail < ApplicationRecord
  belongs_to :contract_person
  belongs_to :source_processing_report
  has_many :contract_person_detail_contract_person_types, dependent: :destroy
  has_many :contract_person_types, through: :contract_person_detail_contract_person_types
end
