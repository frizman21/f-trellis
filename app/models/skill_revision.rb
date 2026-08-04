class SkillRevision < ApplicationRecord
  belongs_to :skill
  # The model this wording runs on, snapshotted when the revision was minted.
  # Optional: revisions written before the column exists carry none, and the
  # queueing path falls back to the skill's preferred model for those.
  belongs_to :model, optional: true
  has_many :source_processing_reports, dependent: :destroy
  has_many :skill_evaluation_results, dependent: :destroy

  before_validation :assign_sequence, on: :create

  private

  def assign_sequence
    return if sequence.present? && sequence.positive?
    return unless skill
    max = skill.skill_revisions.where.not(id: id).maximum(:sequence)
    self.sequence = max.nil? ? 0 : max + 1
  end
end
