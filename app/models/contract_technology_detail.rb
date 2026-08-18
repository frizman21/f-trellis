class ContractTechnologyDetail < ApplicationRecord
  belongs_to :contract_technology
  belongs_to :source_processing_report
  has_many :contract_technology_detail_contract_technology_types, dependent: :destroy
  has_many :contract_technology_types, through: :contract_technology_detail_contract_technology_types
end
