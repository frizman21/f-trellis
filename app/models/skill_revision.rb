class SkillRevision < ApplicationRecord
  belongs_to :skill
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
