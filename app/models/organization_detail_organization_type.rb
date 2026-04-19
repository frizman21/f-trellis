class OrganizationDetailOrganizationType < ApplicationRecord
  belongs_to :organization_detail
  belongs_to :organization_type
end
