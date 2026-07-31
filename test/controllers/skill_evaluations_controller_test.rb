require "test_helper"
require "zip"

class SkillEvaluationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin)
    @skill = Skill.create!(name: "Evaluated skill")
    @revision = @skill.skill_revisions.create!(content: "Pull the orgs.")
    # One shared timestamp: Model.selectable keeps only the most recent refresh,
    # so two models stamped microseconds apart would not both be offered.
    refreshed_at = Time.current
    @fast = Model.create!(provider: "openai", model_id: "gpt-fast", name: "Fast", last_seen_at: refreshed_at)
    @slow = Model.create!(provider: "openai", model_id: "gpt-slow", name: "Slow", last_seen_at: refreshed_at)
    @source = fetched_source("https://eval.test/a")
    @set = LearningSet.create!(name: "Pages under test")
    @set.add_source(@source)
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

  def evaluation_with(learning_set: nil, models: nil)
    evaluation = SkillEvaluation.create!(name: "Comparison", skill: @skill, base_model: @fast,
                                         learning_set: learning_set || @set)
    evaluation.models = models || [ @fast, @slow ]
    evaluation
  end

  test "index lists evaluations" do
    evaluation_with

    get skill_evaluations_path

    assert_response :success
    assert_match "Comparison", @response.body
  end

  test "the new form offers skills, models and learning sets" do
    get new_skill_evaluation_path

    assert_response :success
    assert_select "select[name=?]", "skill_evaluation[skill_id]"
    assert_select "select[name=?]", "skill_evaluation[base_model_id]"
    assert_select "select[name=?] option", "skill_evaluation[learning_set_id]",
                  text: /Pages under test/
    assert_select "input[name=?][value=?]", "skill_evaluation[model_ids][]", @fast.id.to_s
  end

  test "create persists the learning set and the selected models" do
    assert_difference "SkillEvaluation.count", 1 do
      post skill_evaluations_path, params: {
        skill_evaluation: {
          name: "Comparison", description: "Cheap vs baseline",
          skill_id: @skill.id, learning_set_id: @set.id, base_model_id: @fast.id,
          model_ids: [ @fast.id, @slow.id ]
        }
      }
    end

    evaluation = SkillEvaluation.order(:id).last
    assert_redirected_to skill_evaluation_path(evaluation)
    assert_equal @set, evaluation.learning_set
    assert_equal [ @source ], evaluation.sources.to_a
    assert_equal [ @fast.id, @slow.id ].sort, evaluation.model_ids.sort
  end

  test "create without a name re-renders the form" do
    assert_no_difference "SkillEvaluation.count" do
      post skill_evaluations_path, params: {
        skill_evaluation: { name: "", skill_id: @skill.id, learning_set_id: @set.id,
                            base_model_id: @fast.id }
      }
    end

    assert_response :unprocessable_entity
  end

  test "update replaces the selected models" do
    evaluation = evaluation_with

    patch skill_evaluation_path(evaluation), params: {
      skill_evaluation: {
        name: evaluation.name, skill_id: @skill.id, learning_set_id: @set.id,
        base_model_id: @fast.id, model_ids: [ @slow.id ]
      }
    }

    assert_equal [ @slow.id ], evaluation.reload.model_ids
  end

  test "show carries the configuration and the run button" do
    evaluation = evaluation_with

    get skill_evaluation_path(evaluation)

    assert_response :success
    assert_match "gpt-fast", @response.body
    assert_select "a[href=?]", learning_set_path(@set)
    assert_select "form[action=?]", run_skill_evaluation_path(evaluation)
  end

  test "show warns when the baseline is not among the models being run" do
    evaluation = evaluation_with(models: [ @slow ])

    get skill_evaluation_path(evaluation)

    assert_match(/baseline is not among the models/, @response.body)
  end

  test "run queues one job per source and model pair" do
    evaluation = evaluation_with

    assert_difference "SkillEvaluationResult.count", 2 do
      assert_enqueued_jobs 2, only: RunSkillEvaluationJob do
        post run_skill_evaluation_path(evaluation)
      end
    end

    assert_redirected_to skill_evaluation_path(evaluation)
    follow_redirect!
    assert_match(/Queued 2 runs/, @response.body)
  end

  test "run says why it queued nothing when the learning set is empty" do
    evaluation = evaluation_with(learning_set: LearningSet.create!(name: "Empty set"))

    assert_no_enqueued_jobs only: RunSkillEvaluationJob do
      post run_skill_evaluation_path(evaluation)
    end

    follow_redirect!
    assert_match(/Empty set has no sources/, @response.body)
  end

  test "the results table links to each result" do
    evaluation = evaluation_with
    result = SkillEvaluationResult.create!(skill_evaluation: evaluation, source: @source,
                                           model: @fast, skill_revision: @revision,
                                           status: "complete", response: "Acme Corp")

    get skill_evaluation_path(evaluation)

    assert_select "a[href=?]", skill_evaluation_result_path(result)
    assert_match "Acme Corp", @response.body
  end

  test "a result with no score reads as an em dash rather than a number" do
    evaluation = evaluation_with
    SkillEvaluationResult.create!(skill_evaluation: evaluation, source: @source, model: @fast,
                                  skill_revision: @revision, status: "complete", response: "x")

    get skill_evaluation_path(evaluation)

    assert_select "span[title=?]", "Scoring not implemented yet"
  end

  test "the result page shows the full response" do
    evaluation = evaluation_with
    result = SkillEvaluationResult.create!(skill_evaluation: evaluation, source: @source,
                                           model: @fast, skill_revision: @revision,
                                           status: "complete", response: "A long response body.")

    get skill_evaluation_result_path(result)

    assert_response :success
    assert_match "A long response body.", @response.body
    assert_match "gpt-fast", @response.body
  end

  test "the result page shows the error of a failed run" do
    evaluation = evaluation_with
    result = SkillEvaluationResult.create!(skill_evaluation: evaluation, source: @source,
                                           model: @fast, skill_revision: @revision,
                                           status: "failed", error: "RuntimeError: provider down")

    get skill_evaluation_result_path(result)

    assert_response :success
    assert_match "provider down", @response.body
  end

  test "evaluations require authentication" do
    sign_out users(:admin)

    get skill_evaluations_path

    assert_redirected_to new_user_session_path
  end
end
