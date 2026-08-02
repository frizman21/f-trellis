# An evaluation's results read as a comparison: how much each model would
# contribute, and where it contributes exactly what the baseline already does.
#
# Everything is measured against the baseline's run on the *same page*. A model
# is not compared against the baseline's total — pages differ enormously in how
# much is on them, and a model that only ran on the dense page would otherwise
# look like the strongest.
#
# Volume only. A model that invents organizations ranks well here; the cell
# detail is what keeps that reviewable, and the column says "contribution", not
# "accuracy".
class EvaluationComparison
  # One (page, model) pair. `result` is nil where the pair has not run — an
  # empty cell, which is not the same as a run that proposed nothing.
  Cell = Struct.new(:source, :model, :result, keyword_init: true) do
    def run? = result.present? && result.status == "complete"
    def count = run? ? result.proposal_set.size : nil
  end

  Ranking = Struct.new(:model, :total, :pages, :added_over_base, :pages_identical_to_base,
                       :baseline, keyword_init: true) do
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
    Cell.new(source: source, model: model, result: by_pair[[ source.id, model.id ]])
  end

  # True when this model proposed, on this page, exactly what the baseline did.
  def identical_to_base?(source, model)
    return false if model.id == @evaluation.base_model_id

    result = by_pair[[ source.id, model.id ]]
    result&.same_proposals_as?(baseline_result(source))
  end

  def baseline_result(source) = by_pair[[ source.id, @evaluation.base_model_id ]]

  # Models ordered by what they would contribute, most first. Ties broken by
  # input price ascending: two models contributing the same amount are not equal
  # if one costs twenty times the other.
  def rankings
    @rankings ||= models.map { |model| ranking_for(model) }
                        .sort_by { |r| [ -r.total, r.model.input_price_per_million || Float::INFINITY, r.model.model_id ] }
  end

  private

  def by_pair
    @by_pair ||= @results.index_by { |r| [ r.source_id, r.model_id ] }
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
      baseline: model.id == @evaluation.base_model_id
    )
  end
end
