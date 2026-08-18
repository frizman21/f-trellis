class OrganizationTechnologyType < ApplicationRecord
  has_many :organization_technology_detail_organization_technology_types, dependent: :destroy
  has_many :organization_technology_details, through: :organization_technology_detail_organization_technology_types

  validates :name, presence: true, uniqueness: true
end
