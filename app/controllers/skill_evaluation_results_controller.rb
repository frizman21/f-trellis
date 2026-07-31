class SkillEvaluationResultsController < ApplicationController
  def show
    @result = SkillEvaluationResult.includes(:skill_evaluation, :source, :model, :skill_revision, :chat)
                                   .find(params[:id])
    @evaluation = @result.skill_evaluation
  end
end
