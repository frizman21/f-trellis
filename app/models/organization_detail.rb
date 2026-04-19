class OrganizationDetail < ApplicationRecord
  belongs_to :organization
  belongs_to :source_processing_report
  has_many :organization_detail_organization_types, dependent: :destroy
  has_many :organization_types, through: :organization_detail_organization_types

  validates :name, presence: true
end
