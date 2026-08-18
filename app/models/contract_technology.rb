class ContractTechnology < ApplicationRecord
  belongs_to :contract
  belongs_to :technology
  belongs_to :current_detail, class_name: "ContractTechnologyDetail", optional: true
  has_many :contract_technology_details, dependent: :destroy
end
