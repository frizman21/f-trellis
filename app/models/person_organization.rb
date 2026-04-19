class PersonOrganization < ApplicationRecord
  belongs_to :person
  belongs_to :organization
  belongs_to :current_detail, class_name: "PersonOrganizationDetail", optional: true
  has_many :person_organization_details, dependent: :destroy
end
