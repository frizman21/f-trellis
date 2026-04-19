class PersonOrganizationDetail < ApplicationRecord
  belongs_to :person_organization
  belongs_to :source_processing_report
  has_many :person_organization_detail_person_organization_types, dependent: :destroy
  has_many :person_organization_types, through: :person_organization_detail_person_organization_types
end
