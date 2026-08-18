# Relationships are created and removed from an entity's show page. They carry
# no kind or direction semantics yet.
class RelationshipsController < ApplicationController
  def create
    @relationship = Relationship.new(relationship_params)

    if @relationship.save
      redirect_to entity_path(@relationship.from_entity), notice: "Relationship added."
    else
      redirect_to entity_path(params[:relationship][:from_entity_id]),
                  alert: @relationship.errors.full_messages.to_sentence
    end
  end

  def destroy
    @relationship = Relationship.find(params[:id])
    # Back to whichever end the reader came from, not always the `from` end.
    origin = params[:entity_id].presence || @relationship.from_entity_id
    @relationship.destroy

    redirect_to entity_path(origin), notice: "Relationship removed."
  end

  private

  def relationship_params
    params.require(:relationship).permit(:from_entity_id, :to_entity_id)
  end
end
