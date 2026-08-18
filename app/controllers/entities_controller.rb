# The data side of a project.
class EntitiesController < ApplicationController
  before_action :set_project

  # Entities of one kind. There is no unfiltered list: every entity is reached
  # through its type's card.
  def index
    @entity_type = find_entity_type_by_slug
    # The columns this type asks for, and the values for them preloaded, so the
    # table costs two queries rather than one per cell.
    @columns = @entity_type.index_columns.to_a
    @query = params[:q].to_s.strip
    @sort_attribute = sort_attribute
    @direction = direction

    scope = @project.entities
                    .where(entity_type_id: @entity_type.id)
                    .includes(:entity_type, entity_attribute_values: :entity_type_attribute)

    scope = search(scope)
    scope = sort(scope)

    @entities = scope.page(params[:page]).per(25)
  end

  def show
    @entity = find_entity
    @rows = @entity.attribute_rows
    @relationships = @entity.relationships
                            .includes(:relationship_type, :relationship_type_values,
                                      from_entity: :entity_type, to_entity: :entity_type)
                            .order(:id)
    # The union of columns the kinds of edge on this page ask for. An entity can
    # hold edges of several kinds, so the table shows what any of them declares
    # and leaves the cell blank where a kind has no such attribute.
    @relationship_columns = RelationshipTypeAttribute
                            .displayed_on_index
                            .where(relationship_type_id: @relationships.map(&:relationship_type_id).uniq)
                            .order(:name).to_a
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

  DIRECTIONS = %w[asc desc].freeze

  # An IN against matching value rows rather than a join: an entity matching on
  # two attributes should appear once, and a join would need a DISTINCT that then
  # fights the sort.
  #
  # String values only. A substring match against a number is not a useful
  # question, and the sort controls are the right tool there.
  def search(scope)
    return scope if @query.blank?

    matches = EntityAttributeValue
              .where(entity_id: scope.unscope(:includes).select(:id))
              .where("string_value ILIKE ?", "%#{sanitize_sql_like(@query)}%")
              .select(:entity_id)

    scope.where(id: matches)
  end

  # A LEFT JOIN to the values of exactly the sorted attribute. Left, not inner,
  # so entities with nothing recorded still appear; NULLS LAST so they sort last
  # in both directions rather than bunching at whichever end nulls fall.
  def sort(scope)
    return scope.order(:id) if @sort_attribute.nil?

    join = sanitize_sql_array([
      "LEFT JOIN entity_attribute_values sort_values " \
      "ON sort_values.entity_id = entities.id AND sort_values.entity_type_attribute_id = ?",
      @sort_attribute.id
    ])

    # The column comes from a fixed map and the direction from a two-element
    # list, so neither reaches SQL from the query string unchecked.
    scope.joins(join)
         .order(Arel.sql("sort_values.#{@sort_attribute.value_column} #{@direction} NULLS LAST"))
         .order(:id)
  end

  # Looked up among this type's own attributes, so a sort naming another type's
  # attribute — or one that no longer exists — falls back to the default order
  # rather than erroring. A URL someone kept after a type changed still works.
  def sort_attribute
    name = params[:sort].to_s
    return nil if name.blank?

    @entity_type.entity_type_attributes.detect { |attribute| attribute.name == name }
  end

  def direction
    DIRECTIONS.include?(params[:dir]) ? params[:dir] : "asc"
  end

  def sanitize_sql_like(value) = ActiveRecord::Base.sanitize_sql_like(value)
  def sanitize_sql_array(array) = ActiveRecord::Base.send(:sanitize_sql_array, array)

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
