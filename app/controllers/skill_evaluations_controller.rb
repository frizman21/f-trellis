class SkillEvaluationsController < ApplicationController
  def index
    @evaluations = SkillEvaluation.includes(:skill, :base_model, :models,
                                            learning_set: :sources,
                                            skill: :skill_revisions)
                                  .order(created_at: :desc)
                                  .page(params[:page]).per(25)
    @counts_by_evaluation = counts_for(@evaluations)
  end

  def show
    @evaluation = SkillEvaluation.includes(:models, learning_set: :sources).find(params[:id])
    @revision = @evaluation.current_skill_revision
    @counts = @evaluation.result_counts(revision: @revision)
    @results = @evaluation.skill_evaluation_results
                          .includes(:source, :model, :skill_revision)
                          .order(:source_id, :model_id)
    @comparison = EvaluationComparison.new(evaluation: @evaluation, revision: @revision,
                                           results: @results.to_a)
  end

  def new
    @evaluation = SkillEvaluation.new
    load_choices
    @slate = form_slate_locals(@evaluation)
  end

  def create
    @evaluation = SkillEvaluation.new(evaluation_params)

    if @evaluation.save
      redirect_to skill_evaluation_path(@evaluation),
                  notice: "Evaluation ##{@evaluation.id} created."
    else
      load_choices
      @slate = form_slate_locals(@evaluation)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @evaluation = SkillEvaluation.find(params[:id])
    load_choices
    @slate = form_slate_locals(@evaluation)
  end

  def update
    @evaluation = SkillEvaluation.find(params[:id])

    if @evaluation.update(evaluation_params)
      redirect_to skill_evaluation_path(@evaluation),
                  notice: "Evaluation ##{@evaluation.id} updated."
    else
      load_choices
      @slate = form_slate_locals(@evaluation)
      render :edit, status: :unprocessable_entity
    end
  end

  # The "Models to run" section of the form, on its own.
  #
  # Applying an objective has to re-render the model list, and the list depends
  # on selects that live outside it (learning set, baseline). A turbo frame
  # keeps that a GET of one section rather than a round trip through the whole
  # form, which would throw away everything else the person had typed.
  def model_slate
    load_choices
    render partial: "model_slate", locals: slate_locals
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

  # Status counts for a whole page of evaluations in one grouped query, each
  # scoped to that evaluation's current revision. Asking the model per row would
  # be two queries per evaluation listed.
  def counts_for(evaluations)
    revisions = evaluations.index_with { |e| e.current_skill_revision&.id }
    rows = SkillEvaluationResult.where(skill_evaluation_id: evaluations.map(&:id))
                                .group(:skill_evaluation_id, :skill_revision_id, :status)
                                .count

    evaluations.index_with do |evaluation|
      revision_id = revisions[evaluation]
      next {} if revision_id.nil?

      rows.each_with_object({}) do |((evaluation_id, result_revision_id, status), count), memo|
        memo[status] = count if evaluation_id == evaluation.id && result_revision_id == revision_id
      end
    end
  end

  def load_choices
    @skills = Skill.order(:name)
    @models = Model.selectable
    @learning_sets = LearningSet.left_joins(:learning_set_sources)
                                .select("learning_sets.*, COUNT(learning_set_sources.id) AS source_count")
                                .group("learning_sets.id")
                                .order(:name)
  end

  # The frame as the form first draws it: whatever this evaluation already has.
  # No objective is applied on load — the stored set is the truth, and
  # re-deriving it against a registry that has moved would silently change it.
  def form_slate_locals(evaluation)
    {
      models: @models,
      evaluations: copyable_evaluations,
      learning_set: evaluation.learning_set,
      objective: evaluation.model_objective.presence,
      suggestions: [],
      selected_ids: evaluation.model_ids,
      previous_ids: [],
      count: nil,
      provider: nil,
      source_evaluation: nil,
      evaluation_id: evaluation.id
    }
  end

  # The same frame after an objective button, rebuilt from the form's current
  # values. Built here rather than in the view because the form renders the
  # frame inline the first time and the frame re-renders itself after that, and
  # the two have to agree on what they are drawing.
  def slate_locals
    objective = params[:objective].presence_in(ModelSlate::OBJECTIVES)
    baseline = @models.detect { |m| m.id.to_s == params[:base_model_id].to_s }
    source_evaluation = objective == "copy" ? copyable_evaluations.detect { |e| e.id.to_s == params[:source_evaluation_id].to_s } : nil

    suggestions = if objective
      ModelSlate.call(objective: objective, models: @models, baseline: baseline,
                      count: params[:count], provider: params[:provider],
                      source_evaluation: source_evaluation)
    else
      []
    end

    {
      models: @models,
      evaluations: copyable_evaluations,
      learning_set: LearningSet.find_by(id: params[:learning_set_id]),
      objective: objective,
      suggestions: suggestions,
      # An objective replaces the selection outright; without one the frame is
      # showing what the person already had ticked.
      selected_ids: objective ? suggestions.map { |s| s.model.id } : id_list(:selected),
      # What was ticked before the objective was applied, so it can be put back.
      previous_ids: objective ? id_list(:selected) : id_list(:previous),
      count: params[:count],
      provider: params[:provider],
      source_evaluation: source_evaluation,
      evaluation_id: params[:evaluation_id].presence
    }
  end

  # Evaluations whose model set is worth copying: ones that have a set at all.
  def copyable_evaluations
    @copyable_evaluations ||= SkillEvaluation.includes(:models)
                                             .where(id: SkillEvaluationModel.select(:skill_evaluation_id))
                                             .order(created_at: :desc)
                                             .limit(50)
                                             .to_a
  end

  def id_list(key)
    Array(params[key]).filter_map { |value| value.presence&.to_i }
  end

  def evaluation_params
    params.require(:skill_evaluation)
          .permit(:name, :description, :skill_id, :learning_set_id, :base_model_id,
                  :model_objective, model_ids: [])
  end
end
