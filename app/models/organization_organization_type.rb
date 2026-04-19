class OrganizationOrganizationType < ApplicationRecord
  has_many :org_org_typings, dependent: :destroy
  has_many :organization_organization_details, through: :org_org_typings
end
