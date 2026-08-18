# Relationships are created and removed from an entity's show page, within a
# project. They carry no kind or direction semantics yet.
class RelationshipsController < ApplicationController
  before_action :set_project

  def create
    @relationship = @project.relationships.new(relationship_params)

    if @relationship.save
      redirect_to project_entity_path(@project, @relationship.from_entity),
                  notice: "Relationship added."
    else
      redirect_to project_entity_path(@project, params[:relationship][:from_entity_id]),
                  alert: @relationship.errors.full_messages.to_sentence
    end
  end

  def destroy
    @relationship = @project.relationships.find(params[:id])
    # Back to whichever end the reader came from, not always the `from` end.
    origin = params[:entity_id].presence || @relationship.from_entity_id
    @relationship.destroy

    redirect_to project_entity_path(@project, origin), notice: "Relationship removed."
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def relationship_params
    params.require(:relationship).permit(:from_entity_id, :to_entity_id)
  end
end
