class ProjectsController < ApplicationController
  def index
    # The listing shows how much each project holds on each of its two sides,
    # so the counts are loaded with it rather than one query per row.
    @projects = Project.includes(:entity_types, :entities).order(:name)
  end

  # A project's structure is its entity types and the relationship types between
  # them — one idea, so one page. Reading either alone was never enough.
  #
  # "Structure" rather than "ontology" is what the product calls this screen; the
  # code keeps the modelling vocabulary.
  def structure
    @project = Project.find(params[:id])
    @entity_types = @project.entity_types.includes(:entity_type_attributes, :entities)
    @relationship_types = @project.relationship_types
                                  .includes(:relationship_type_attributes,
                                            :from_entity_type, :to_entity_type)
  end

  # A project's data is not one list, it is a list per kind of thing, so the
  # view is a card per entity type rather than a heading over everything at
  # once. Counts come from one grouped query, not one per card.
  def show
    @project = Project.find(params[:id])
    @entity_types = @project.entity_types.includes(:entity_type_attributes)
    @counts = @project.entities.kept.group(:entity_type_id).count
  end

  # Generated from the project's structure rather than stored, so it cannot
  # drift from the structure it describes.
  def ai_configuration
    @project = Project.find(params[:id])
    @prompt = ExtractionPrompt.new(@project)
  end

  def new
    @project = Project.new
  end

  def create
    @project = Project.new(project_params)

    if @project.save
      redirect_to projects_path, notice: "Project \"#{@project.name}\" created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @project = Project.find(params[:id])
  end

  def update
    @project = Project.find(params[:id])

    if @project.update(project_params)
      redirect_to projects_path, notice: "Project \"#{@project.name}\" updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def project_params
    params.require(:project).permit(:name, :default_model_id, :extraction_attempts)
  end
end
