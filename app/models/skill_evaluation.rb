# One question: "how does this skill do on these pages, across these models?"
#
# The evaluation holds the configuration — a skill, a learning set naming the
# pages, the models to try — and owns one result per (page, model) run. The
# pages come from a LearningSet rather than a list of this evaluation's own: two
# evaluations pointed at the same set are comparable, and a set curated once
# stays curated. Running never writes into the knowledge graph; see
# RunSkillEvaluationJob.
class SkillEvaluation < ApplicationRecord
  belongs_to :skill
  belongs_to :learning_set
  # The model the others are compared against. Scoring is not implemented yet,
  # so nothing reads this beyond the UI — it is recorded so scoring can.
  belongs_to :base_model, class_name: "Model"

  has_many :skill_evaluation_models, dependent: :destroy
  has_many :models, through: :skill_evaluation_models
  has_many :skill_evaluation_results, dependent: :destroy

  validates :name, presence: true

  # The pages to run against, as the learning set holds them now. A page added
  # to the set later is simply part of the next run.
  def sources
    learning_set.sources
  end

  # The wording a run would use. Results record the revision they ran, so editing
  # the skill makes every pair runnable again rather than overwriting history.
  def current_skill_revision
    skill.skill_revisions.order(:sequence).last
  end

  # Pairs a run would cover — the whole point of the configuration.
  def planned_pair_count
    sources.count * models.count
  end

  # True when the baseline is not among the models being run, so nothing will
  # produce the output the others are meant to be compared against.
  def base_model_missing_from_run?
    models.exclude?(base_model)
  end
end
