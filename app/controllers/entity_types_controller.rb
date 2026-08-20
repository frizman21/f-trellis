# The entity half of a project's structure.
class EntityTypesController < ApplicationController
  before_action :set_project

  def show
    @entity_type = find_entity_type
    @relationship_types = relationship_types_touching(@entity_type)
  end

  def new
    @entity_type = @project.entity_types.new
  end

  def create
    @entity_type = @project.entity_types.new(entity_type_params)

    if @entity_type.save
      redirect_to project_entity_type_path(@project, @entity_type),
                  notice: "Entity type \"#{@entity_type.name}\" created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @entity_type = find_entity_type
  end

  def update
    @entity_type = find_entity_type

    if @entity_type.update(entity_type_params)
      redirect_to project_entity_type_path(@project, @entity_type),
                  notice: "Entity type \"#{@entity_type.name}\" updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @entity_type = find_entity_type

    if @entity_type.destroy
      redirect_to structure_project_path(@project),
                  notice: "Entity type \"#{@entity_type.name}\" deleted."
    else
      # restrict_with_error: a type with entities of it still in the project is
      # not something to cascade away silently.
      redirect_to project_entity_type_path(@project, @entity_type),
                  alert: @entity_type.errors.full_messages.to_sentence
    end
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def find_entity_type
    @project.entity_types.find(params[:id])
  end

  # Every relationship type with this entity type at either end.
  #
  # One `or` rather than two queries added together: a type whose ends are both
  # this type — one engine superseding another — is in both halves, and the
  # database returning it once is cheaper and harder to get wrong than
  # remembering to dedupe afterwards.
  #
  # Scoped through the project to match find_entity_type above, not because the
  # scope is load-bearing: RelationshipType#ends_are_in_this_project already
  # guarantees a type's ends belong to its own project, so filtering on an end's
  # id cannot cross one. Removing `@project.` here changes no result today —
  # it is here so a future query that does not have that guarantee inherits the
  # habit rather than the exception.
  #
  # `includes` covers the three associations each row reads. Without it the
  # fifteen relationship types F-DoD's Person sits in are forty-five queries.
  # Order comes from RelationshipType's default scope.
  def relationship_types_touching(entity_type)
    @project.relationship_types
            .where(from_entity_type_id: entity_type.id)
            .or(@project.relationship_types.where(to_entity_type_id: entity_type.id))
            .includes(:from_entity_type, :to_entity_type, :relationship_type_attributes)
  end

  def entity_type_params
    params.require(:entity_type).permit(
      :name, :description,
      entity_type_attributes_attributes: [ :id, :name, :value_type,
                                           :is_displayed_on_index, :is_disabled, :_destroy ]
    )
  end
end
