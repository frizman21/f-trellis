class SourceProcessingReport < ApplicationRecord
  STATUSES = %w[new processing complete failed].freeze

  belongs_to :source
  belongs_to :skill_revision
  belongs_to :model, optional: true
  belongs_to :chat, optional: true

  validates :status, inclusion: { in: STATUSES }
  has_many :person_details, dependent: :destroy
  has_many :organization_details, dependent: :destroy
  has_many :facility_details, dependent: :destroy
  has_many :part_details, dependent: :destroy
  has_many :person_organization_details, dependent: :destroy
  has_many :person_person_details, dependent: :destroy
  has_many :organization_organization_details, dependent: :destroy
  has_many :part_organization_details, dependent: :destroy
  has_many :part_part_details, dependent: :destroy
end
