class Technology < ApplicationRecord
  has_many :technology_details, dependent: :destroy

  has_many :part_technologies, dependent: :destroy
  has_many :parts, through: :part_technologies

  has_many :science_technologies, dependent: :destroy
  has_many :sciences, through: :science_technologies

  # Who is behind the technology. The contract is the funded work; the direct
  # organization edge is for what a contract cannot say — adoption, licensing,
  # or internal R&D with no award in evidence. See issue #185.
  has_many :contract_technologies, dependent: :destroy
  has_many :contracts, through: :contract_technologies

  has_many :organization_technologies, dependent: :destroy
  has_many :organizations, through: :organization_technologies

  belongs_to :current_detail, class_name: "TechnologyDetail", optional: true
end
