class Contract < ApplicationRecord
  has_many :contract_details, dependent: :destroy

  has_many :contract_organizations, dependent: :destroy
  has_many :organizations, through: :contract_organizations

  has_many :contract_people, dependent: :destroy
  has_many :people, through: :contract_people

  has_many :contract_technologies, dependent: :destroy
  has_many :technologies, through: :contract_technologies

  has_many :contract_parts, dependent: :destroy
  has_many :parts, through: :contract_parts

  belongs_to :current_detail, class_name: "ContractDetail", optional: true
end
