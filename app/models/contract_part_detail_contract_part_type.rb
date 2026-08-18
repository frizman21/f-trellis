class ContractPartDetailContractPartType < ApplicationRecord
  belongs_to :contract_part_detail
  belongs_to :contract_part_type
end
