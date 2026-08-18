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

  def edit
    @relationship = find_relationship
    @relationship.build_missing_attribute_values
    build_missing_citations
  end

  def update
    @relationship = find_relationship

    if @relationship.update(relationship_params)
      redirect_to project_entity_path(@project, @relationship.from_entity),
                  notice: "Relationship updated."
    else
      @relationship.build_missing_attribute_values
      build_missing_citations
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @relationship = find_relationship
    # Back to whichever end the reader came from, not always the `from` end.
    origin = params[:entity_id].presence || @relationship.from_entity_id
    @relationship.destroy

    redirect_to project_entity_path(@project, origin), notice: "Relationship removed."
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def find_relationship
    @project.relationships.find(params[:id])
  end

  def build_missing_citations
    @relationship.relationship_type_values.each do |value|
      value.relationship_type_value_sources.build if value.relationship_type_value_sources.empty?
    end
  end

  def relationship_params
    params.require(:relationship).permit(
      :from_entity_id, :to_entity_id, :relationship_type_id,
      relationship_sources_attributes: [ :id, :source_id, :confidence ],
      relationship_type_values_attributes: [
        :id, :relationship_type_attribute_id, :value,
        { relationship_type_value_sources_attributes: [ :id, :source_id, :confidence ] }
      ]
    )
  end
end
