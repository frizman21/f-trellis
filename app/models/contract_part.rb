class ContractPart < ApplicationRecord
  belongs_to :contract
  belongs_to :part
  belongs_to :current_detail, class_name: "ContractPartDetail", optional: true
  has_many :contract_part_details, dependent: :destroy
end
