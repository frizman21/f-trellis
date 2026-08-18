class ContractDetailContractType < ApplicationRecord
  belongs_to :contract_detail
  belongs_to :contract_type
end
