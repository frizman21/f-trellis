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
    # Kept only. The counts beside them deliberately are not — see
    # OntologyHelper#instance_count, which says how many of the rows are deleted
    # rather than omitting them.
    @entity_types = @project.entity_types.kept.includes(:entity_type_attributes)
    @relationship_types = @project.relationship_types.kept
                                  .includes(:relationship_type_attributes,
                                            :from_entity_type, :to_entity_type)

    # Four grouped queries, the same shape #show already uses for its cards.
    # Emphatically not `includes(:entities)` and a count in Ruby: F-DoD holds
    # 352,894 entities and 1,015,988 relationships, and loading them to find out
    # how many are deleted would make this page unopenable.
    @entity_counts = counts_by(@project.entities, :entity_type_id)
    @relationship_counts = counts_by(@project.relationships, :relationship_type_id)
  end

  # A project's data is not one list, it is a list per kind of thing, so the
  # view is a card per entity type rather than a heading over everything at
  # once. Counts come from one grouped query, not one per card.
  def show
    @project = Project.find(params[:id])
    @entity_types = @project.entity_types.kept.includes(:entity_type_attributes)
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

  # Kept and deleted totals per type id, defaulting to zero so a type with no
  # instances at all needs no branch at the call site.
  def counts_by(scope, column)
    { kept: scope.kept.group(column).count,
      deleted: scope.discarded.group(column).count }
  end

  def project_params
    params.require(:project).permit(:name, :default_model_id, :extraction_attempts)
  end
end
