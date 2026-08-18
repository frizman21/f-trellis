# The ontology side of a project.
class EntityTypesController < ApplicationController
  before_action :set_project

  def index
    @entity_types = @project.entity_types
  end

  def show
    @entity_type = find_entity_type
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
      redirect_to project_entity_types_path(@project),
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

  def entity_type_params
    params.require(:entity_type).permit(:name, :description)
  end
end
