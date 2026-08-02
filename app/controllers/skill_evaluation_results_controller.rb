class SkillEvaluationResultsController < ApplicationController
  def show
    @result = SkillEvaluationResult.includes(:skill_evaluation, :source, :model, :skill_revision, :chat)
                                   .find(params[:id])
    @evaluation = @result.skill_evaluation
    # The baseline's run on the *same page and the same wording* — the only
    # thing this result means anything against.
    @baseline = @evaluation.skill_evaluation_results
                           .find_by(source_id: @result.source_id,
                                    model_id: @evaluation.base_model_id,
                                    skill_revision_id: @result.skill_revision_id)
  end
end
