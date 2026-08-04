# An evaluation's results read as a comparison: how far each model agrees with
# the baseline, and how much it would contribute.
#
# Everything is measured against the baseline's run on the *same page*. A model
# is not compared against the baseline's total — pages differ enormously in how
# much is on them, and a model that only ran on the dense page would otherwise
# look like the strongest.
#
# The baseline defines correctness here. It is a stand-in for truth, not truth:
# where the baseline missed something, a model that found it is scored as having
# invented it. That is why the columns say "agreement" rather than "accuracy",
# and why the cell detail stays one click away.
#
# Contribution is still reported — "how much would this add" is a real question —
# but it is not what the ranking sorts on. It cannot be: a model that invents
# entities out-contributes one that reads the page correctly.
class EvaluationComparison
  # How one run lines up with the baseline's run on the same page.
  #
  # `agreed` + `missed` is what the baseline proposed; `agreed` + `invented` is
  # what this run proposed. The ratios are left undefined rather than zero when
  # their denominator is empty, so "nothing to compare against" stays
  # distinguishable from "agreed on nothing" — the two look identical in a
  # column of numbers and mean opposite things.
  Agreement = Struct.new(:agreed, :missed, :invented, :pages, keyword_init: true) do
    def comparable? = pages.positive?

    # Of what the baseline found, how much did this run also find?
    def recall
      total = agreed + missed
      total.zero? ? nil : agreed.to_f / total
    end

    # Of what this run proposed, how much did the baseline back up?
    def precision
      total = agreed + invented
      total.zero? ? nil : agreed.to_f / total
    end

    # Harmonic mean, so a run cannot score well by being either indiscriminate
    # or timid. Nil when neither ratio is defined; zero when they are defined
    # and there is simply no overlap.
    def f1
      r = recall
      p = precision
      return nil if r.nil? && p.nil?

      r = r.to_f
      p = p.to_f
      (r + p).zero? ? 0.0 : 2 * r * p / (r + p)
    end
  end

  # One (page, model) pair. `result` is nil where the pair has not run — an
  # empty cell, which is not the same as a run that proposed nothing.
  Cell = Struct.new(:source, :model, :result, :agreement, keyword_init: true) do
    def run? = result.present? && result.status == "complete"
    def count = run? ? result.proposal_set.size : nil
  end

  Ranking = Struct.new(:model, :total, :pages, :added_over_base, :pages_identical_to_base,
                       :baseline, :agreement, keyword_init: true) do
    def mean_per_page = pages.zero? ? 0.0 : total.to_f / pages
  end

  def initialize(evaluation:, revision:, results: nil)
    @evaluation = evaluation
    @revision = revision
    @results = (results || evaluation.skill_evaluation_results).select { |r| r.skill_revision_id == revision&.id }
  end

  def sources = @sources ||= @evaluation.sources.to_a.sort_by(&:id)

  # Columns, baseline first — it is what the others are read against, so it
  # belongs at the left edge rather than wherever the sort put it.
  def models
    @models ||= begin
      all = @evaluation.models_to_run.sort_by { |m| [ m.provider, m.model_id ] }
      base = @evaluation.base_model
      [ base ] + all.reject { |m| m.id == base&.id }
    end
  end

  def any_results? = @results.any?

  def cell(source, model)
    Cell.new(source: source, model: model,
             result: by_pair[[ source.id, model.id ]],
             agreement: agreement_on(source, model))
  end

  # True when this model proposed, on this page, exactly what the baseline did.
  def identical_to_base?(source, model)
    return false if model.id == @evaluation.base_model_id

    result = by_pair[[ source.id, model.id ]]
    result&.same_proposals_as?(baseline_result(source))
  end

  def baseline_result(source) = by_pair[[ source.id, @evaluation.base_model_id ]]

  # Models ordered by how far they agree with the baseline, closest first.
  #
  # The baseline is pinned to the top rather than sorted: it is the yardstick,
  # and scoring it against itself would put a meaningless 100% at whatever
  # position the sort happened to give it.
  #
  # Ties are broken by input price ascending, as before — two models agreeing to
  # the same degree are not equal if one costs twenty times the other. A model
  # with nothing comparable sorts last, since no agreement is not high agreement.
  def rankings
    @rankings ||= begin
      all = models.map { |model| ranking_for(model) }
      base, rest = all.partition(&:baseline)
      base + rest.sort_by do |r|
        [ -(r.agreement.f1 || -1.0), r.model.input_price_per_million || Float::INFINITY, r.model.model_id ]
      end
    end
  end

  private

  def by_pair
    @by_pair ||= @results.index_by { |r| [ r.source_id, r.model_id ] }
  end

  # Nil for the baseline's own column, and for a pair where either side did not
  # complete — a page the baseline never ran has no truth to score against, and
  # calling the model's proposals invented there would punish it for the
  # baseline's gap.
  def agreement_on(source, model)
    return nil if model.id == @evaluation.base_model_id

    mine = by_pair[[ source.id, model.id ]]
    base = baseline_result(source)
    return nil unless mine&.status == "complete" && base&.status == "complete"

    Agreement.new(
      agreed: mine.proposal_set.shared_with(base.proposal_set).size,
      missed: mine.proposal_set.missing_from(base.proposal_set).size,
      invented: mine.proposal_set.added_over(base.proposal_set).size,
      pages: 1
    )
  end

  def ranking_for(model)
    completed = sources.filter_map { |source| [ source, by_pair[[ source.id, model.id ]] ] }
                       .select { |_, result| result&.status == "complete" }

    added = completed.sum do |source, result|
      base = baseline_result(source)
      base ? result.proposal_set.added_over(base.proposal_set).size : result.proposal_set.size
    end

    Ranking.new(
      model: model,
      total: completed.sum { |_, result| result.proposal_set.size },
      pages: completed.size,
      added_over_base: added,
      pages_identical_to_base: completed.count { |source, _| identical_to_base?(source, model) },
      baseline: model.id == @evaluation.base_model_id,
      agreement: agreement_for(model)
    )
  end

  # Micro-averaged: the counts are summed across pages and the ratios taken once
  # at the end, matching how `added_over_base` already sums per page. Averaging
  # per-page ratios instead would let a sparse page where the baseline found two
  # things weigh as heavily as a dense one where it found ninety.
  def agreement_for(model)
    per_page = sources.filter_map { |source| agreement_on(source, model) }

    Agreement.new(
      agreed: per_page.sum(&:agreed),
      missed: per_page.sum(&:missed),
      invented: per_page.sum(&:invented),
      pages: per_page.size
    )
  end
end
