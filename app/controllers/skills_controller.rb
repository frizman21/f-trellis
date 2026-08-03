class SkillsController < ApplicationController
  def index
    @skills = Skill.left_joins(:skill_revisions)
                   .select("skills.*, COUNT(skill_revisions.id) AS revision_count")
                   .group("skills.id")
                   .order(:name)
  end

  def show
    @skill = Skill.find(params[:id])
    # Ordered by sequence, matching Skill#current_revision — created_at can
    # disagree, and sequence is what the unique index and the pointer use.
    @revisions = @skill.skill_revisions.includes(:model).order(sequence: :desc)
    @current_revision = @revisions.first
  end

  def new
    @skill = Skill.new
    @revision_content = ""
    load_models
  end

  def create
    @skill = Skill.new(skill_params)
    @revision_content = revision_content_param

    Skill.transaction do
      @skill.save!
      @skill.skill_revisions.create!(content: @revision_content, model: @skill.preferred_model)
    end

    redirect_to skill_path(@skill), notice: "Skill ##{@skill.id} created with initial revision."
  rescue ActiveRecord::RecordInvalid
    load_models
    render :new, status: :unprocessable_entity
  end

  def edit
    @skill = Skill.find(params[:id])
    @revision_content = @skill.skill_revisions.order(created_at: :desc).first&.content.to_s
    load_models
  end

  def update
    @skill = Skill.find(params[:id])
    @revision_content = revision_content_param

    minted = false

    Skill.transaction do
      @skill.update!(skill_params)

      # A revision records a change to what runs — the wording or the model.
      # Saving the form without touching either edits the skill's own
      # attributes and mints nothing, so the revision list stays a history of
      # changes rather than a log of visits to this page.
      if @skill.revision_changed?(content: @revision_content, model: @skill.preferred_model)
        @skill.skill_revisions.create!(content: @revision_content, model: @skill.preferred_model)
        minted = true
      end
    end

    notice = if minted
      "Skill ##{@skill.id} updated; new revision added."
    else
      "Skill ##{@skill.id} updated; no revision added (wording and model unchanged)."
    end

    redirect_to skill_path(@skill), notice: notice
  rescue ActiveRecord::RecordInvalid
    load_models
    render :edit, status: :unprocessable_entity
  end

  private

  def skill_params
    params.require(:skill).permit(:name, :purpose, :applicability, :url_patterns_text,
                                  :is_active, :preferred_model_id)
  end

  def revision_content_param
    params.dig(:skill, :revision_content).to_s
  end

  def load_models
    @models = Model.selectable
  end
end
