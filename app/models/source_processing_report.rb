class SourceProcessingReport < ApplicationRecord
  belongs_to :source
  belongs_to :skill_revision
  has_many :person_details, dependent: :destroy
  has_many :organization_details, dependent: :destroy
  has_many :facility_details, dependent: :destroy
  has_many :person_organization_details, dependent: :destroy
  has_many :person_person_details, dependent: :destroy
  has_many :organization_organization_details, dependent: :destroy
end
