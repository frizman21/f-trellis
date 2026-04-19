class OrganizationOrganizationDetail < ApplicationRecord
  belongs_to :organization_organization
  belongs_to :source_processing_report
  has_many :org_org_typings, dependent: :destroy
  has_many :organization_organization_types, through: :org_org_typings
end
