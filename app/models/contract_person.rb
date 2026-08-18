class ContractPerson < ApplicationRecord
  belongs_to :contract
  belongs_to :person
  belongs_to :current_detail, class_name: "ContractPersonDetail", optional: true
  has_many :contract_person_details, dependent: :destroy
end
