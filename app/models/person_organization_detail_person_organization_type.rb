class PersonOrganizationDetailPersonOrganizationType < ApplicationRecord
  belongs_to :person_organization_detail
  belongs_to :person_organization_type
end
