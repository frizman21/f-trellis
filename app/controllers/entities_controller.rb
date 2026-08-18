# The data side of a project.
class EntitiesController < ApplicationController
  before_action :set_project

  # Entities of one kind. There is no unfiltered list: every entity is reached
  # through its type's card.
  def index
    @entity_type = find_entity_type_by_slug
    @entities = @project.entities
                        .where(entity_type_id: @entity_type.id)
                        .includes(:entity_type, entity_attribute_values: :entity_type_attribute)
                        .order(:id)
                        .page(params[:page]).per(25)
  end

  def show
    @entity = find_entity
    @rows = @entity.attribute_rows
    @relationships = @entity.relationships
                            .includes(from_entity: :entity_type, to_entity: :entity_type)
                            .order(:id)
  end

  # Creating is two steps: pick the type here, fill in its attributes on the
  # edit page. One form whose fields change with the type dropdown would need
  # JavaScript to re-render; this needs none.
  def new
    @entity = @project.entities.new
    # One blank citation row for the form to bind to. Left empty it is rejected,
    # which is how "no source" is said.
    @entity.entity_sources.build
  end

  def create
    @entity = @project.entities.new(entity_params)

    if @entity.save
      redirect_to edit_project_entity_path(@project, @entity),
                  notice: "Entity created. Fill in its attributes."
    else
      @entity.entity_sources.build if @entity.entity_sources.empty?
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @entity = find_entity
    @entity.build_missing_attribute_values
    build_missing_citations
  end

  def update
    @entity = find_entity

    if @entity.update(entity_params)
      redirect_to project_entity_path(@project, @entity), notice: "Entity updated."
    else
      @entity.build_missing_attribute_values
      build_missing_citations
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @entity = find_entity
    label = @entity.label
    @entity.destroy

    redirect_to project_path(@project), notice: "Entity \"#{label}\" deleted."
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  # Slugs are derived from names rather than stored, so the lookup compares
  # derived slugs. A project has a handful of types and they are one query away;
  # this is what keeps a type's name and its address in step by construction.
  def find_entity_type_by_slug
    slug = params[:type_slug].to_s
    @project.entity_types.detect { |type| type.slug == slug } ||
      raise(ActiveRecord::RecordNotFound, "no entity type at #{slug.inspect}")
  end

  # Always through the project. An id from another project is then a 404 by
  # construction rather than by a check someone has to remember to write.
  def find_entity
    @project.entities.includes(entity_attribute_values: :entity_type_attribute).find(params[:id])
  end

  # A blank citation row per value, so every attribute can be given a source
  # without the form growing an "add source" step.
  def build_missing_citations
    @entity.entity_attribute_values.each do |value|
      value.entity_attribute_value_sources.build if value.entity_attribute_value_sources.empty?
    end
  end

  def entity_params
    params.require(:entity).permit(
      :entity_type_id,
      entity_sources_attributes: [ :id, :source_id, :confidence ],
      entity_attribute_values_attributes: [
        :id, :entity_type_attribute_id, :value,
        { entity_attribute_value_sources_attributes: [ :id, :source_id, :confidence ] }
      ]
    )
  end
end
