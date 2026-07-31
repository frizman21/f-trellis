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

  test "the baseline is flagged when it is not among the models being run" do
    other = Model.create!(provider: "anthropic", model_id: "claude-eval", name: "Other",
                          last_seen_at: Time.current)
    e = evaluation
    e.models = [ other ]

    assert e.base_model_missing_from_run?

    e.models = [ other, @model ]

    assert_not e.reload.base_model_missing_from_run?
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
end
