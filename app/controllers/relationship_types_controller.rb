# The relationship half of a project's ontology.
class RelationshipTypesController < ApplicationController
  before_action :set_project

  def index
    @relationship_types = @project.relationship_types
  end

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

    if @relationship_type.destroy
      redirect_to project_relationship_types_path(@project),
                  notice: "Relationship type \"#{@relationship_type.name}\" deleted."
    else
      # restrict_with_error: edges of this kind still exist, and deleting the
      # kind out from under them would leave them meaning nothing.
      redirect_to project_relationship_type_path(@project, @relationship_type),
                  alert: @relationship_type.errors.full_messages.to_sentence
    end
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def find_relationship_type
    @project.relationship_types.find(params[:id])
  end

  def relationship_type_params
    params.require(:relationship_type).permit(:name, :description,
                                             :from_entity_type_id, :to_entity_type_id)
  end
end
