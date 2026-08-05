require "test_helper"

class SkillEvaluationTest < ActiveSupport::TestCase
  setup do
    @skill = Skill.create!(name: "Evaluated skill")
    @revision = @skill.skill_revisions.create!(content: "Pull the orgs.")
    @model = Model.create!(provider: "openai", model_id: "gpt-eval", name: "Eval",
                           last_seen_at: Time.current)
  end

  def evaluation(**attrs)
    set = attrs.delete(:learning_set) || LearningSet.create!(name: "Set #{SecureRandom.hex(4)}")
    SkillEvaluation.create!({ name: "Run", skill: @skill, base_model: @model,
                              learning_set: set }.merge(attrs))
  end

  # A two-page, one-model evaluation: two pairs, so a run can be half done.
  def two_pair_evaluation
    set = LearningSet.create!(name: "Pages under test")
    @page_a = set.add_url("https://eval.test/a").source
    @page_b = set.add_url("https://eval.test/b").source
    e = evaluation(learning_set: set)
    e.models = [ @model ]
    e
  end

  def result_for(evaluation, source, status, revision: @revision, **attrs)
    SkillEvaluationResult.create!({ skill_evaluation: evaluation, source: source,
                                    model: @model, skill_revision: revision,
                                    status: status }.merge(attrs))
  end

  test "an evaluation requires a name, a skill, a learning set and a base model" do
    blank = SkillEvaluation.new

    assert_not blank.valid?
    assert_includes blank.errors[:name], "can't be blank"
    assert_includes blank.errors.attribute_names, :skill
    assert_includes blank.errors.attribute_names, :learning_set
    assert_includes blank.errors.attribute_names, :base_model
  end

  test "current_skill_revision is the latest revision of the skill" do
    latest = @skill.skill_revisions.create!(content: "Pull the orgs, but better.")

    assert_equal latest, evaluation.current_skill_revision
  end

  test "the pages come from the learning set" do
    set = LearningSet.create!(name: "Pages under test")
    set.add_url("https://eval.test/a")
    e = evaluation(learning_set: set)

    assert_equal [ "https://eval.test/a" ], e.sources.map(&:url)
  end

  test "planned pair count is the set's sources times the models" do
    set = LearningSet.create!(name: "Pages under test")
    set.add_url("https://eval.test/a")
    set.add_url("https://eval.test/b")
    e = evaluation(learning_set: set)
    e.models = [ @model ]

    assert_equal 2, e.planned_pair_count
  end

  test "a page added to the set later is part of the next run" do
    set = LearningSet.create!(name: "Pages under test")
    e = evaluation(learning_set: set)
    e.models = [ @model ]
    assert_equal 0, e.planned_pair_count

    set.add_url("https://eval.test/added-later")

    assert_equal 1, e.reload.planned_pair_count
  end

  test "a learning set an evaluation points at cannot be deleted" do
    set = LearningSet.create!(name: "Pages under test")
    evaluation(learning_set: set)

    assert_not set.destroy
    assert set.persisted?
  end

  test "a model cannot be added to the same evaluation twice" do
    e = evaluation
    SkillEvaluationModel.create!(skill_evaluation: e, model: @model)

    duplicate = SkillEvaluationModel.new(skill_evaluation: e, model: @model)

    assert_not duplicate.valid?
  end

  test "the same source, model and revision cannot be run twice" do
    e = evaluation
    source = Source.create!(url: "https://eval.test/a")
    attrs = { skill_evaluation: e, source: source, model: @model,
              skill_revision: @revision, status: "pending" }
    SkillEvaluationResult.create!(attrs)

    assert_not SkillEvaluationResult.new(attrs).valid?
  end

  test "a new revision makes the same pair runnable again" do
    e = evaluation
    source = Source.create!(url: "https://eval.test/a")
    SkillEvaluationResult.create!(skill_evaluation: e, source: source, model: @model,
                                  skill_revision: @revision, status: "complete")
    later = @skill.skill_revisions.create!(content: "Reworded.")

    assert SkillEvaluationResult.new(skill_evaluation: e, source: source, model: @model,
                                     skill_revision: later, status: "pending").valid?
  end

  test "a result rejects an unknown status" do
    e = evaluation
    result = SkillEvaluationResult.new(skill_evaluation: e, source: Source.create!(url: "https://eval.test/a"),
                                       model: @model, skill_revision: @revision, status: "whatever")

    assert_not result.valid?
    assert_includes result.errors.attribute_names, :status
  end

  # Every number on the comparison is relative to the baseline's output on the
  # same page, so an evaluation that skipped it would have nothing to read the
  # other columns against.
  test "the baseline is run whether or not it was ticked" do
    other = Model.create!(provider: "anthropic", model_id: "claude-eval", name: "Other",
                          last_seen_at: Time.current)
    e = evaluation
    e.models = [ other ]

    assert_equal [ other, @model ], e.models_to_run
  end

  test "a ticked baseline is not run twice" do
    other = Model.create!(provider: "anthropic", model_id: "claude-eval", name: "Other",
                          last_seen_at: Time.current)
    e = evaluation
    e.models = [ other, @model ]

    assert_equal 2, e.models_to_run.size
    assert_equal 1, e.models_to_run.count(@model)
  end

  # An evaluation is configured once and run repeatedly, so the set it holds can
  # name a model that has gone out of circulation since.
  test "models that went deprecated or disabled are not run" do
    deprecated = Model.create!(provider: "anthropic", model_id: "claude-gone", name: "Gone",
                               last_seen_at: Time.current, is_deprecated: true)
    disabled = Model.create!(provider: "anthropic", model_id: "claude-off", name: "Off",
                             last_seen_at: Time.current, is_disabled: true)
    e = evaluation
    e.models = [ deprecated, disabled ]

    assert_equal [ @model ], e.models_to_run
  end

  test "an unusable baseline leaves nothing to run" do
    other = Model.create!(provider: "anthropic", model_id: "claude-eval", name: "Other",
                          last_seen_at: Time.current)
    e = evaluation
    e.models = [ other ]
    @model.update!(is_deprecated: true)

    assert_empty e.reload.models_to_run
  end

  test "destroying an evaluation takes its models and results with it" do
    e = evaluation
    source = Source.create!(url: "https://eval.test/a")
    e.models = [ @model ]
    SkillEvaluationResult.create!(skill_evaluation: e, source: source, model: @model,
                                  skill_revision: @revision, status: "pending")

    assert_difference [ "SkillEvaluationModel.count", "SkillEvaluationResult.count" ], -1 do
      e.destroy!
    end
  end

  # --- run status ---------------------------------------------------------

  test "an evaluation with no results has not been run" do
    assert_equal :not_run, two_pair_evaluation.run_status
  end

  test "a pair still queued or in flight reads as running" do
    e = two_pair_evaluation
    result_for(e, @page_a, "complete")
    result_for(e, @page_b, "pending")

    assert_equal :running, e.run_status

    e.skill_evaluation_results.find_by(source: @page_b).update!(status: "running")

    assert_equal :running, e.run_status
  end

  test "every pair complete reads as complete" do
    e = two_pair_evaluation
    result_for(e, @page_a, "complete")
    result_for(e, @page_b, "complete")

    assert_equal :complete, e.run_status
  end

  test "a finished run with one failure is not reported as complete" do
    e = two_pair_evaluation
    result_for(e, @page_a, "complete")
    result_for(e, @page_b, "failed")

    assert_equal :complete_with_failures, e.run_status
  end

  test "every pair failing reads as failed" do
    e = two_pair_evaluation
    result_for(e, @page_a, "failed")
    result_for(e, @page_b, "failed")

    assert_equal :failed, e.run_status
  end

  test "fewer results than pairs, with nothing in flight, reads as incomplete" do
    e = two_pair_evaluation
    result_for(e, @page_a, "complete")

    assert_equal :incomplete, e.run_status
  end

  test "a page added to the set moves a complete evaluation back to incomplete" do
    e = two_pair_evaluation
    result_for(e, @page_a, "complete")
    result_for(e, @page_b, "complete")
    assert_equal :complete, e.run_status

    e.learning_set.add_url("https://eval.test/c")

    assert_equal :incomplete, e.reload.run_status
  end

  # The number people read as progress must describe the wording being run now,
  # or it reports "12 of 6" after a single edit.
  test "counts ignore results from an earlier revision" do
    e = two_pair_evaluation
    result_for(e, @page_a, "complete")
    result_for(e, @page_b, "complete")

    @skill.skill_revisions.create!(content: "Reworded.")

    assert_equal({}, e.result_counts)
    assert_equal :not_run, e.run_status
  end

  test "result counts are keyed by status" do
    e = two_pair_evaluation
    result_for(e, @page_a, "complete")
    result_for(e, @page_b, "failed")

    assert_equal({ "complete" => 1, "failed" => 1 }, e.result_counts)
  end

  test "a skill with no revision has nothing to count" do
    skill = Skill.create!(name: "Draft only")
    e = evaluation(skill: skill)

    assert_equal({}, e.result_counts)
    assert_equal :not_run, e.run_status
  end

  test "a freshly queued pair is not stalled" do
    e = two_pair_evaluation
    result_for(e, @page_a, "pending")

    assert_not e.stalled?
  end

  test "a pair queued longer than the stale window is stalled" do
    e = two_pair_evaluation
    result = result_for(e, @page_a, "pending")
    result.update_columns(updated_at: (SkillEvaluation::STALE_AFTER + 1.minute).ago)

    assert e.stalled?
  end

  test "an old finished pair is not stalled" do
    e = two_pair_evaluation
    result = result_for(e, @page_a, "complete")
    result.update_columns(updated_at: 1.day.ago)

    assert_not e.stalled?
  end
end
