class OrganizationTechnologyDetail < ApplicationRecord
  belongs_to :organization_technology
  belongs_to :source_processing_report
  has_many :organization_technology_detail_organization_technology_types, dependent: :destroy
  has_many :organization_technology_types, through: :organization_technology_detail_organization_technology_types
end
