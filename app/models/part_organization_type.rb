class PartOrganizationType < ApplicationRecord
  has_many :part_organization_detail_part_organization_types, dependent: :destroy
  has_many :part_organization_details, through: :part_organization_detail_part_organization_types
end
