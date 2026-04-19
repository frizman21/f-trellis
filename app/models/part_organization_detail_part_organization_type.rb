class PartOrganizationDetailPartOrganizationType < ApplicationRecord
  belongs_to :part_organization_detail
  belongs_to :part_organization_type
end
