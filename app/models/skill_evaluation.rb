# One question: "how does this skill do on these pages, across these models?"
#
# The evaluation holds the configuration — a skill, a learning set naming the
# pages, the models to try — and owns one result per (page, model) run. The
# pages come from a LearningSet rather than a list of this evaluation's own: two
# evaluations pointed at the same set are comparable, and a set curated once
# stays curated. Running never writes into the knowledge graph; see
# RunSkillEvaluationJob.
class SkillEvaluation < ApplicationRecord
  # How long a pair may sit in `pending`/`running` before we stop calling it
  # progress. Jobs are fanned out one per pair and nothing re-queues them, so a
  # job the queue drops — the development `:async` adapter does not survive a
  # restart — would otherwise read as "running" forever.
  STALE_AFTER = 15.minutes

  belongs_to :skill
  belongs_to :learning_set
  # The model everything else is scored against.
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
  #
  # Sorted in Ruby rather than SQL so a preloaded association is used as loaded —
  # the evaluations index asks every row for this, and `.order(...).last` would
  # re-query each time. A skill has a handful of revisions, not thousands.
  def current_skill_revision
    skill.skill_revisions.max_by(&:sequence)
  end

  # The models a run actually covers: the ones ticked, plus the baseline whether
  # it was ticked or not.
  #
  # Every number on the comparison — proposals not in the baseline, pages
  # identical to it, the ranking itself — is relative to the baseline's output on
  # the same page, so an evaluation that skipped it would produce columns and
  # nothing to read them against. Enforced here rather than warned about on the
  # page, because a warning is something you read after the run has already cost
  # money.
  def models_to_run
    ticked = models.to_a
    ticked.include?(base_model) ? ticked : ticked + [ base_model ].compact
  end

  # Pairs a run would cover — the whole point of the configuration. `size`, not
  # `count`, so a preloaded association is used as loaded rather than re-queried.
  def planned_pair_count
    sources.size * models_to_run.size
  end

  # Results by status for one revision, e.g. {"complete" => 4, "failed" => 1}.
  #
  # Counted at the current revision by default, because that is the run people
  # mean: editing the skill makes a new revision and a fresh set of pairs, and
  # counting every result ever run would report "12 of 6" after one edit.
  def result_counts(revision: current_skill_revision)
    return {} if revision.nil?

    skill_evaluation_results.where(skill_revision: revision).group(:status).count
  end

  # Where this evaluation stands, derived from the result rows rather than
  # stored. A stored column would need every job completion to keep it in sync
  # and would drift the moment a job was dropped; the rows are already the truth.
  def run_status(counts: result_counts, planned: planned_pair_count)
    done = counts.values.sum
    return :not_run if done.zero?
    return :running if counts.values_at("pending", "running").compact.sum.positive?

    failed = counts["failed"].to_i
    return :incomplete if done < planned
    return :failed if failed == done

    failed.positive? ? :complete_with_failures : :complete
  end

  # Pairs that have been sitting long enough that the job behind them is more
  # likely gone than slow. Reported, not repaired — nothing re-queues a pair.
  def stalled?(revision: current_skill_revision)
    return false if revision.nil?

    skill_evaluation_results
      .where(skill_revision: revision, status: %w[pending running])
      .where(updated_at: ..STALE_AFTER.ago)
      .exists?
  end
end
