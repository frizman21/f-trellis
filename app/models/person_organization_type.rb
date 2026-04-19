class PersonOrganizationType < ApplicationRecord
  has_many :person_organization_detail_person_organization_types, dependent: :destroy
  has_many :person_organization_details, through: :person_organization_detail_person_organization_types
end
