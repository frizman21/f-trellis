class SourceProcessingReport < ApplicationRecord
  STATUSES = %w[new processing complete failed].freeze

  belongs_to :source
  belongs_to :skill_revision
  belongs_to :model, optional: true
  belongs_to :chat, optional: true

  validates :status, inclusion: { in: STATUSES }
  # One run per (source, skill revision, content). Re-fetching a page whose
  # content did not change, or resubmitting the form, must not pay twice.
  validates :content_hash, uniqueness: { scope: [ :source_id, :skill_revision_id ] },
                           allow_nil: true

  before_validation :assign_content_hash, on: :create

  # The report, if any, that already covers this source's current content for
  # this skill revision.
  def self.covering(source:, skill_revision:)
    hash = source&.source_data&.order(:created_at)&.last&.content_hash
    return nil if hash.blank?

    find_by(source: source, skill_revision: skill_revision, content_hash: hash)
  end
  has_many :person_details, dependent: :destroy
  has_many :organization_details, dependent: :destroy
  has_many :facility_details, dependent: :destroy
  has_many :part_details, dependent: :destroy
  has_many :science_details, dependent: :destroy
  has_many :technology_details, dependent: :destroy
  has_many :contract_details, dependent: :destroy
  has_many :person_organization_details, dependent: :destroy
  has_many :person_person_details, dependent: :destroy
  has_many :organization_organization_details, dependent: :destroy
  has_many :part_organization_details, dependent: :destroy
  has_many :part_part_details, dependent: :destroy
  has_many :part_technology_details, dependent: :destroy
  has_many :science_technology_details, dependent: :destroy
  has_many :person_science_details, dependent: :destroy
  has_many :contract_organization_details, dependent: :destroy
  has_many :contract_person_details, dependent: :destroy
  has_many :contract_technology_details, dependent: :destroy
  has_many :contract_part_details, dependent: :destroy
  has_many :organization_technology_details, dependent: :destroy

  private

  def assign_content_hash
    return if content_hash.present?

    self.content_hash = source&.source_data&.order(:created_at)&.last&.content_hash
  end
end
