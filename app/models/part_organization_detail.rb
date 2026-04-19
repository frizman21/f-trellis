class PartOrganizationDetail < ApplicationRecord
  belongs_to :part_organization
  belongs_to :source_processing_report
  has_many :part_organization_detail_part_organization_types, dependent: :destroy
  has_many :part_organization_types, through: :part_organization_detail_part_organization_types
end
