# Relationships are created and removed from an entity's show page, within a
# project. They carry no kind or direction semantics yet.
class RelationshipsController < ApplicationController
  before_action :set_project

  def create
    @relationship = @project.relationships.new(relationship_params)

    if save_with_manual_run(@relationship)
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
    set_compatible_types
  end

  def update
    @relationship = find_relationship

    @relationship.assign_attributes(relationship_params)

    if save_with_manual_run(@relationship)
      redirect_to project_entity_path(@project, @relationship.from_entity),
                  notice: "Relationship updated."
    else
      @relationship.build_missing_attribute_values
      build_missing_citations
      set_compatible_types
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @relationship = find_relationship
    # Back to whichever end the reader came from, not always the `from` end.
    origin = params[:entity_id].presence || @relationship.from_entity_id
    @relationship.discard

    redirect_to project_entity_path(@project, origin), notice: "Relationship removed."
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  # Citations a person entered need a run of their own before they will save.
  # In a transaction with the record, so a failed save leaves no run behind
  # claiming an edit that never happened.
  def save_with_manual_run(relationship)
    ActiveRecord::Base.transaction do
      ManualCitationRun.stamp!(project: @project, citations: citations_of(relationship))
      raise ActiveRecord::Rollback unless relationship.save

      true
    end
  end

  def citations_of(relationship)
    relationship.relationship_extraction_runs +
      relationship.relationship_type_values.flat_map(&:relationship_type_value_extraction_runs)
  end

  def find_relationship
    @project.relationships.kept.find(params[:id])
  end

  # Retyping an edge is only possible to a kind whose declared ends match the
  # two entities it already joins.
  def set_compatible_types
    @compatible_types = @project.relationship_types.kept.where(
      from_entity_type_id: @relationship.from_entity.entity_type_id,
      to_entity_type_id: @relationship.to_entity.entity_type_id
    )
  end

  def build_missing_citations
    @relationship.relationship_type_values.each do |value|
      value.relationship_type_value_extraction_runs.build if value.relationship_type_value_extraction_runs.empty?
    end
  end

  def relationship_params
    params.require(:relationship).permit(
      :from_entity_id, :to_entity_id, :relationship_type_id,
      relationship_extraction_runs_attributes: [ :id, :source_id, :confidence ],
      relationship_type_values_attributes: [
        :id, :relationship_type_attribute_id, :value,
        { relationship_type_value_extraction_runs_attributes: [ :id, :source_id, :confidence ] }
      ]
    )
  end
end
