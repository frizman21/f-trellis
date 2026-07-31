# One run of one skill revision, on one page, through one model.
class SkillEvaluationResult < ApplicationRecord
  STATUSES = %w[pending running complete failed].freeze

  belongs_to :skill_evaluation
  belongs_to :source
  belongs_to :model
  belongs_to :skill_revision
  belongs_to :chat, optional: true

  validates :status, inclusion: { in: STATUSES }
  # One run per (page, model, wording). Pressing Run twice must not pay twice;
  # editing the skill makes a new revision, and with it a new pair to run.
  validates :source_id, uniqueness: { scope: [ :skill_evaluation_id, :model_id, :skill_revision_id ] }

  scope :ordered, -> { order(created_at: :desc, id: :desc) }

  def duration_seconds
    return nil if started_at.blank? || completed_at.blank?

    completed_at - started_at
  end
end
