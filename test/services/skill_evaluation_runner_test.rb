require "test_helper"
require "zip"

class SkillEvaluationRunnerTest < ActiveJob::TestCase
  setup do
    @skill = Skill.create!(name: "Evaluated skill")
    @revision = @skill.skill_revisions.create!(content: "Pull the orgs.")
    @fast = Model.create!(provider: "openai", model_id: "gpt-fast", name: "Fast", last_seen_at: Time.current)
    @slow = Model.create!(provider: "openai", model_id: "gpt-slow", name: "Slow", last_seen_at: Time.current)

    @a = fetched_source("https://eval.test/a")
    @b = fetched_source("https://eval.test/b")

    @set = LearningSet.create!(name: "Pages under test")
    @set.add_source(@a)
    @set.add_source(@b)

    @evaluation = SkillEvaluation.create!(name: "Run", skill: @skill, base_model: @fast,
                                          learning_set: @set)
    @evaluation.models = [ @fast, @slow ]
  end

  def fetched_source(url)
    source = Source.create!(url: url)
    source.update!(status: "complete")
    bytes = Zip::OutputStream.write_buffer do |zos|
      zos.put_next_entry("page.html")
      zos.write("<html><body><p>Acme Corp</p></body></html>")
    end
    bytes.rewind
    SourceDatum.create!(source: source, content_type: "application/zip", data: bytes.read)
    source
  end

  test "queues one run per source and model pair" do
    outcome = nil

    assert_difference "SkillEvaluationResult.count", 4 do
      assert_enqueued_jobs 4, only: RunSkillEvaluationJob do
        outcome = SkillEvaluationRunner.call(evaluation: @evaluation)
      end
    end

    assert_equal 4, outcome.queued.size
    assert_equal [ @revision ], outcome.queued.map(&:skill_revision).uniq
    assert_equal [ "pending" ], outcome.queued.map(&:status).uniq
  end

  test "running twice does not pay for the same pair again" do
    SkillEvaluationRunner.call(evaluation: @evaluation)

    outcome = nil
    assert_no_difference "SkillEvaluationResult.count" do
      assert_no_enqueued_jobs only: RunSkillEvaluationJob do
        outcome = SkillEvaluationRunner.call(evaluation: @evaluation)
      end
    end

    assert_equal 4, outcome.skipped.size
    assert_match(/already run at this revision/, outcome.summary)
  end

  test "editing the skill makes every pair runnable again" do
    SkillEvaluationRunner.call(evaluation: @evaluation)
    @skill.skill_revisions.create!(content: "Reworded.")

    assert_difference "SkillEvaluationResult.count", 4 do
      SkillEvaluationRunner.call(evaluation: @evaluation)
    end
  end

  test "a source with no fetched content is skipped rather than sent empty" do
    @set.add_url("https://eval.test/empty")

    outcome = nil
    assert_enqueued_jobs 4, only: RunSkillEvaluationJob do
      outcome = SkillEvaluationRunner.call(evaluation: @evaluation)
    end

    assert_equal 2, outcome.skipped.size
    assert_match(/no fetched content/, outcome.summary)
  end

  test "a skill with no revision blocks the run and says so" do
    skill = Skill.create!(name: "Draft only")
    evaluation = SkillEvaluation.create!(name: "Nothing to run", skill: skill, base_model: @fast,
                                         learning_set: @set)
    evaluation.models = [ @fast ]

    outcome = nil
    assert_no_enqueued_jobs only: RunSkillEvaluationJob do
      outcome = SkillEvaluationRunner.call(evaluation: evaluation)
    end

    assert outcome.blocked?
    assert_match(/no revisions/, outcome.summary)
  end

  test "an empty learning set blocks the run and names the set" do
    @set.learning_set_sources.destroy_all

    outcome = SkillEvaluationRunner.call(evaluation: @evaluation.reload)

    assert outcome.blocked?
    assert_match(/Pages under test has no sources/, outcome.summary)
  end

  test "a page added to the set is picked up by the next run" do
    SkillEvaluationRunner.call(evaluation: @evaluation)
    @set.add_source(fetched_source("https://eval.test/c"))

    assert_difference "SkillEvaluationResult.count", 2 do
      SkillEvaluationRunner.call(evaluation: @evaluation.reload)
    end
  end

  # Nothing ticked is not nothing to run: the baseline is what everything else
  # would be compared against, so it goes in regardless.
  test "an evaluation with nothing ticked still runs the baseline" do
    @evaluation.models = []

    outcome = SkillEvaluationRunner.call(evaluation: @evaluation.reload)

    assert_not outcome.blocked?
    assert_equal [ @evaluation.base_model ], outcome.queued.map(&:model).uniq
  end
end
