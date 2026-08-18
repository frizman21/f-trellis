class ContractPartDetail < ApplicationRecord
  belongs_to :contract_part
  belongs_to :source_processing_report
  has_many :contract_part_detail_contract_part_types, dependent: :destroy
  has_many :contract_part_types, through: :contract_part_detail_contract_part_types
end
