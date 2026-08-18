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
                                  .includes(:relationship_type_attributes, :relationships,
                                            :from_entity_type, :to_entity_type)
  end

  def data
    @project = Project.find(params[:id])
    @entities = @project.entities
                        .includes(:entity_type, entity_attribute_values: :entity_type_attribute)
                        .order(:id)
                        .page(params[:page]).per(25)
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
    params.require(:project).permit(:name)
  end
end
