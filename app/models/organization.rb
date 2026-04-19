class Organization < ApplicationRecord
  has_many :organization_details, dependent: :destroy
  belongs_to :current_detail, class_name: "OrganizationDetail", optional: true
end
