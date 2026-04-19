class PartOrganization < ApplicationRecord
  belongs_to :part
  belongs_to :organization
  belongs_to :current_detail, class_name: "PartOrganizationDetail", optional: true
  has_many :part_organization_details, dependent: :destroy
end
