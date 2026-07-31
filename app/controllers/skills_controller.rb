class SkillsController < ApplicationController
  def index
    @skills = Skill.left_joins(:skill_revisions)
                   .select("skills.*, COUNT(skill_revisions.id) AS revision_count")
                   .group("skills.id")
                   .order(:name)
  end

  def show
    @skill = Skill.find(params[:id])
    @revisions = @skill.skill_revisions.order(created_at: :desc)
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
      @skill.skill_revisions.create!(content: @revision_content)
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

    Skill.transaction do
      @skill.update!(skill_params)
      @skill.skill_revisions.create!(content: @revision_content)
    end

    redirect_to skill_path(@skill), notice: "Skill ##{@skill.id} updated; new revision added."
  rescue ActiveRecord::RecordInvalid
    load_models
    render :edit, status: :unprocessable_entity
  end

  private

  def skill_params
    params.require(:skill).permit(:name, :purpose, :applicability, :is_active, :preferred_model_id)
  end

  def revision_content_param
    params.dig(:skill, :revision_content).to_s
  end

  def load_models
    @models = Model.selectable
  end
end
