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

  # What this run would have added to the knowledge base, as a set.
  def proposal_set
    @proposal_set ||= ProposalSet.new(proposals)
  end

  # Stores what the run proposed, plus the two things derived from it: the digest
  # that answers "identical to the baseline?" in one comparison, and the score.
  #
  # `score` is the count of *distinct* proposals — a model that emits the same
  # organization twice contributed it once. Volume only: this says how much a run
  # would add, not whether any of it is right, which is why it is labelled
  # "contribution" wherever it is shown.
  def record_proposals(records)
    set = ProposalSet.new(records)
    self.proposals = set.distinct
    self.proposal_digest = set.digest
    self.score = set.size
    @proposal_set = set
  end

  # True when this run proposed exactly what `other` did — the case where a
  # cheaper model is free money.
  def same_proposals_as?(other)
    other.present? && proposal_digest.present? && proposal_digest == other.proposal_digest
  end
end
