class OrganizationTechnology < ApplicationRecord
  belongs_to :organization
  belongs_to :technology
  belongs_to :current_detail, class_name: "OrganizationTechnologyDetail", optional: true
  has_many :organization_technology_details, dependent: :destroy
end
