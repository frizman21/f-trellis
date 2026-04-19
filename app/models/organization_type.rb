class OrganizationType < ApplicationRecord
  has_many :organization_detail_organization_types, dependent: :destroy
  has_many :organization_details, through: :organization_detail_organization_types
end
