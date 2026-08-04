require "test_helper"

class EvaluationComparisonTest < ActiveSupport::TestCase
  # Model.current keeps only the rows stamped by the most recent refresh, so
  # every model here shares one timestamp.
  STAMP = Time.utc(2026, 7, 31, 12, 0, 0)

  setup do
    @skill = Skill.create!(name: "Compared skill")
    @revision = @skill.skill_revisions.create!(content: "Pull the orgs.")
    @base  = build_model("gpt-base", 3.0)
    @cheap = build_model("gpt-cheap", 0.1)
    @dear  = build_model("gpt-dear", 30.0)

    @set = LearningSet.create!(name: "Compared pages")
    @page_a = @set.add_url("https://compare.test/a").source
    @page_b = @set.add_url("https://compare.test/b").source

    @evaluation = SkillEvaluation.create!(name: "Comparison", skill: @skill, base_model: @base,
                                          learning_set: @set)
    @evaluation.models = [ @base, @cheap, @dear ]
  end

  def build_model(model_id, price)
    Model.create!(provider: "openai", model_id: model_id, name: model_id, last_seen_at: STAMP,
                  pricing: { "text_tokens" => { "standard" => { "input_per_million" => price } } })
  end

  def org(name) = { "type" => "organization", "name" => name, "attributes" => {} }

  # Named for what it does, not `run` — Minitest owns that name on a TestCase.
  def record_run(source, model, proposals, status: "complete")
    result = SkillEvaluationResult.new(skill_evaluation: @evaluation, source: source, model: model,
                                       skill_revision: @revision, status: status)
    result.record_proposals(proposals)
    result.save!
    result
  end

  def comparison = EvaluationComparison.new(evaluation: @evaluation, revision: @revision)

  test "the baseline is the first column" do
    assert_equal @base, comparison.models.first
  end

  test "a cell reports the count and a pair that has not run is left empty" do
    record_run(@page_a, @cheap, [ org("acme"), org("beta") ])

    assert_equal 2, comparison.cell(@page_a, @cheap).count
    assert_nil comparison.cell(@page_b, @cheap).result
    assert_nil comparison.cell(@page_b, @cheap).count
  end

  test "a run that proposed nothing is a zero, not an empty cell" do
    record_run(@page_a, @cheap, [])

    assert_equal 0, comparison.cell(@page_a, @cheap).count
  end

  test "a cell is marked identical when it proposed exactly what the baseline did" do
    record_run(@page_a, @base,  [ org("acme"), org("beta") ])
    record_run(@page_a, @cheap, [ org("beta"), org("acme") ])
    record_run(@page_a, @dear,  [ org("acme") ])

    assert comparison.identical_to_base?(@page_a, @cheap), "order must not matter"
    assert_not comparison.identical_to_base?(@page_a, @dear)
  end

  test "the baseline is never marked identical to itself" do
    record_run(@page_a, @base, [ org("acme") ])

    assert_not comparison.identical_to_base?(@page_a, @base)
  end

  test "a failed run contributes nothing to the ranking" do
    record_run(@page_a, @cheap, [ org("acme") ], status: "failed")

    ranking = comparison.rankings.detect { |r| r.model == @cheap }
    assert_equal 0, ranking.total
    assert_equal 0, ranking.pages
  end

  # The reason this change exists. Under volume scoring @dear won this ordering
  # by proposing two things the page does not support; under agreement it loses
  # to the model that proposed exactly what the baseline did.
  test "rankings order by agreement, not by contribution" do
    record_run(@page_a, @base,  [ org("acme") ])
    record_run(@page_a, @cheap, [ org("acme") ])
    record_run(@page_a, @dear,  [ org("acme"), org("beta"), org("gamma") ])

    assert_equal [ @base, @cheap, @dear ], comparison.rankings.map(&:model)
  end

  test "the baseline is pinned first and scores no agreement against itself" do
    record_run(@page_a, @base,  [ org("acme") ])
    record_run(@page_a, @cheap, [ org("acme") ])

    ranking = comparison.rankings.first
    assert_equal @base, ranking.model
    assert ranking.baseline
    assert_nil ranking.agreement.f1
    assert_not ranking.agreement.comparable?
  end

  # Two models contributing the same amount are not equal if one costs thirty
  # times the other.
  test "a tie on contribution is broken by price ascending" do
    record_run(@page_a, @cheap, [ org("acme") ])
    record_run(@page_a, @dear,  [ org("beta") ])

    ordered = comparison.rankings.map(&:model)
    assert_operator ordered.index(@cheap), :<, ordered.index(@dear)
  end

  test "a ranking counts what the model added over the baseline and where it matched" do
    record_run(@page_a, @base,  [ org("acme") ])
    record_run(@page_b, @base,  [ org("gamma") ])
    record_run(@page_a, @cheap, [ org("acme") ])
    record_run(@page_b, @cheap, [ org("gamma"), org("delta") ])

    ranking = comparison.rankings.detect { |r| r.model == @cheap }
    assert_equal 3, ranking.total
    assert_equal 2, ranking.pages
    assert_in_delta 1.5, ranking.mean_per_page
    assert_equal 1, ranking.added_over_base, "only delta is new"
    assert_equal 1, ranking.pages_identical_to_base, "page a matched, page b did not"
  end

  def agreement_for(model) = comparison.rankings.detect { |r| r.model == model }.agreement

  test "a run proposing exactly the baseline's records agrees completely" do
    record_run(@page_a, @base,  [ org("acme"), org("beta") ])
    record_run(@page_a, @cheap, [ org("beta"), org("acme") ])

    agreement = agreement_for(@cheap)
    assert_equal 2, agreement.agreed
    assert_equal 0, agreement.missed
    assert_equal 0, agreement.invented
    assert_in_delta 1.0, agreement.recall
    assert_in_delta 1.0, agreement.precision
    assert_in_delta 1.0, agreement.f1
  end

  # Timid, not wrong: everything it said was right, it just stopped early.
  # Volume scoring cannot tell this apart from the case below.
  test "a run finding half the baseline's records keeps full precision" do
    record_run(@page_a, @base,  [ org("acme"), org("beta") ])
    record_run(@page_a, @cheap, [ org("acme") ])

    agreement = agreement_for(@cheap)
    assert_equal 1, agreement.agreed
    assert_equal 1, agreement.missed
    assert_equal 0, agreement.invented
    assert_in_delta 0.5, agreement.recall
    assert_in_delta 1.0, agreement.precision
  end

  # The Bio Reader failure: everything the baseline found, plus a pile the page
  # does not support. Full recall, poor precision — and under the old ranking
  # this was the top-scoring run.
  test "a run inventing records keeps full recall but loses precision" do
    record_run(@page_a, @base,  [ org("acme") ])
    record_run(@page_a, @cheap, [ org("acme"), org("b"), org("c"), org("d"), org("e") ])

    agreement = agreement_for(@cheap)
    assert_equal 1, agreement.agreed
    assert_equal 0, agreement.missed
    assert_equal 4, agreement.invented
    assert_in_delta 1.0, agreement.recall
    assert_in_delta 0.2, agreement.precision
  end

  # Zero and "nothing to compare" are the same shape in a column of numbers and
  # mean opposite things, so they must not both render as 0%.
  test "a run proposing nothing scores zero agreement, not an undefined one" do
    record_run(@page_a, @base,  [ org("acme"), org("beta") ])
    record_run(@page_a, @cheap, [])

    agreement = agreement_for(@cheap)
    assert_equal 0, agreement.agreed
    assert_equal 2, agreement.missed
    assert_in_delta 0.0, agreement.recall
    assert_in_delta 0.0, agreement.f1, 0.001, "no overlap is zero agreement"
    assert agreement.comparable?
  end

  test "a model with no baseline to compare against has an undefined agreement" do
    record_run(@page_a, @cheap, [ org("acme") ])

    agreement = agreement_for(@cheap)
    assert_not agreement.comparable?
    assert_nil agreement.f1
    assert_nil agreement.recall
  end

  # A page the baseline never ran has no truth on it. Scoring the model's
  # proposals there as invented would punish it for the baseline's gap.
  test "a page the baseline did not run is left out of the agreement entirely" do
    record_run(@page_a, @base,  [ org("acme") ])
    record_run(@page_a, @cheap, [ org("acme") ])
    record_run(@page_b, @cheap, [ org("gamma"), org("delta") ])

    agreement = agreement_for(@cheap)
    assert_equal 1, agreement.pages, "only page a is comparable"
    assert_equal 0, agreement.invented, "page b's proposals are not held against it"
    assert_in_delta 1.0, agreement.f1
  end

  # Micro-averaged: summed then divided, so the dense page carries its weight.
  # Per-page averaging would score this 0.75 instead.
  test "agreement sums counts across pages before taking the ratio" do
    record_run(@page_a, @base,  [ org("a1") ])
    record_run(@page_a, @cheap, [ org("a1") ])
    record_run(@page_b, @base,  [ org("b1"), org("b2"), org("b3"), org("b4") ])
    record_run(@page_b, @cheap, [ org("b1"), org("b2") ])

    agreement = agreement_for(@cheap)
    assert_equal 3, agreement.agreed
    assert_equal 2, agreement.missed
    assert_in_delta 0.6, agreement.recall, 0.001, "3 of 5 overall, not the mean of 1.0 and 0.5"
  end

  test "a tie on agreement is broken by price ascending" do
    record_run(@page_a, @base,  [ org("acme") ])
    record_run(@page_a, @cheap, [ org("acme") ])
    record_run(@page_a, @dear,  [ org("acme") ])

    ordered = comparison.rankings.map(&:model)
    assert_operator ordered.index(@cheap), :<, ordered.index(@dear)
  end

  test "a model with nothing comparable ranks below one that agreed" do
    record_run(@page_a, @base,  [ org("acme") ])
    record_run(@page_a, @dear,  [ org("acme") ])
    record_run(@page_b, @cheap, [ org("gamma") ])

    ordered = comparison.rankings.map(&:model)
    assert_operator ordered.index(@dear), :<, ordered.index(@cheap),
                    "no agreement is not high agreement, even at a lower price"
  end

  test "a cell carries the agreement for its page" do
    record_run(@page_a, @base,  [ org("acme"), org("beta") ])
    record_run(@page_a, @cheap, [ org("acme"), org("zeta") ])

    agreement = comparison.cell(@page_a, @cheap).agreement
    assert_equal 1, agreement.agreed
    assert_equal 1, agreement.missed
    assert_equal 1, agreement.invented
    assert_nil comparison.cell(@page_a, @base).agreement, "the baseline has none of its own"
  end

  # Results from an earlier wording are not part of this run's comparison.
  test "results at another revision are ignored" do
    older = @skill.skill_revisions.create!(content: "Pull the orgs, differently.")
    SkillEvaluationResult.create!(skill_evaluation: @evaluation, source: @page_a, model: @cheap,
                                  skill_revision: older, status: "complete",
                                  proposals: [ org("acme") ], score: 1)

    assert_nil comparison.cell(@page_a, @cheap).result
  end
end
