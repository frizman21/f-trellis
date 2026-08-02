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

  test "rankings order by total contribution, most first" do
    record_run(@page_a, @base,  [ org("acme") ])
    record_run(@page_a, @cheap, [ org("acme") ])
    record_run(@page_a, @dear,  [ org("acme"), org("beta"), org("gamma") ])

    assert_equal [ @dear, @cheap, @base ], comparison.rankings.map(&:model)
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

  # Results from an earlier wording are not part of this run's comparison.
  test "results at another revision are ignored" do
    older = @skill.skill_revisions.create!(content: "Pull the orgs, differently.")
    SkillEvaluationResult.create!(skill_evaluation: @evaluation, source: @page_a, model: @cheap,
                                  skill_revision: older, status: "complete",
                                  proposals: [ org("acme") ], score: 1)

    assert_nil comparison.cell(@page_a, @cheap).result
  end
end
