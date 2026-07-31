class SkillEvaluationsController < ApplicationController
  def index
    @evaluations = SkillEvaluation.includes(:skill, :base_model, :models, learning_set: :sources)
                                  .order(created_at: :desc)
                                  .page(params[:page]).per(25)
  end

  def show
    @evaluation = SkillEvaluation.includes(:models, learning_set: :sources).find(params[:id])
    @revision = @evaluation.current_skill_revision
    @results = @evaluation.skill_evaluation_results
                          .includes(:source, :model, :skill_revision)
                          .order(:source_id, :model_id)
  end

  def new
    @evaluation = SkillEvaluation.new
    load_choices
  end

  def create
    @evaluation = SkillEvaluation.new(evaluation_params)

    if @evaluation.save
      redirect_to skill_evaluation_path(@evaluation),
                  notice: "Evaluation ##{@evaluation.id} created."
    else
      load_choices
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @evaluation = SkillEvaluation.find(params[:id])
    load_choices
  end

  def update
    @evaluation = SkillEvaluation.find(params[:id])

    if @evaluation.update(evaluation_params)
      redirect_to skill_evaluation_path(@evaluation),
                  notice: "Evaluation ##{@evaluation.id} updated."
    else
      load_choices
      render :edit, status: :unprocessable_entity
    end
  end

  # One run per (source, model) pair, queued in the background.
  def run
    evaluation = SkillEvaluation.find(params[:id])
    outcome = SkillEvaluationRunner.call(evaluation: evaluation)

    if outcome.blocked?
      redirect_to skill_evaluation_path(evaluation), alert: outcome.summary
    else
      redirect_to skill_evaluation_path(evaluation), notice: outcome.summary
    end
  end

  private

  def load_choices
    @skills = Skill.order(:name)
    @models = Model.selectable
    @learning_sets = LearningSet.left_joins(:learning_set_sources)
                                .select("learning_sets.*, COUNT(learning_set_sources.id) AS source_count")
                                .group("learning_sets.id")
                                .order(:name)
  end

  def evaluation_params
    params.require(:skill_evaluation)
          .permit(:name, :description, :skill_id, :learning_set_id, :base_model_id, model_ids: [])
  end
end
