# The relationship half of a project's structure.
class RelationshipTypesController < ApplicationController
  before_action :set_project

  def show
    @relationship_type = find_relationship_type
  end

  def new
    @relationship_type = @project.relationship_types.new
  end

  def create
    @relationship_type = @project.relationship_types.new(relationship_type_params)

    if @relationship_type.save
      redirect_to project_relationship_type_path(@project, @relationship_type),
                  notice: "Relationship type \"#{@relationship_type.name}\" created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @relationship_type = find_relationship_type
  end

  def update
    @relationship_type = find_relationship_type

    if @relationship_type.update(relationship_type_params)
      redirect_to project_relationship_type_path(@project, @relationship_type),
                  notice: "Relationship type \"#{@relationship_type.name}\" updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @relationship_type = find_relationship_type

    # Soft, and it takes the edges of this kind with it — see
    # RelationshipType#discard_with_relationships. The old restrict_with_error
    # branch is gone: it refused whenever any relationship row existed,
    # including ones already removed through the UI, which made a type with a
    # deleted edge undeletable forever (#66).
    @relationship_type.discard_with_relationships

    redirect_to structure_project_path(@project),
                notice: "Relationship type \"#{@relationship_type.name}\" deleted."
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def find_relationship_type
    @project.relationship_types.kept.find(params[:id])
  end

  def relationship_type_params
    params.require(:relationship_type).permit(
      :name, :description, :from_entity_type_id, :to_entity_type_id,
      relationship_type_attributes_attributes: [ :id, :name, :value_type,
                                                 :is_displayed_on_index, :is_disabled, :_destroy ]
    )
  end
end
