class Organization < ApplicationRecord
  has_many :organization_details, dependent: :destroy
  has_many :person_organizations, dependent: :destroy
  has_many :people, through: :person_organizations
  belongs_to :current_detail, class_name: "OrganizationDetail", optional: true
end
