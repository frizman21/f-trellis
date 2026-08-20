require "administrate/base_dashboard"

class EntityDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    deleted_at: Field::DateTime,
    entity_attribute_values: Field::HasMany,
    entity_sources: Field::HasMany,
    entity_type: Field::BelongsTo,
    incoming_relationships: Field::HasMany,
    name: Field::String,
    outgoing_relationships: Field::HasMany,
    project: Field::BelongsTo,
    sources: Field::HasMany,
    created_at: Field::DateTime,
    updated_at: Field::DateTime,
  }.freeze

  # COLLECTION_ATTRIBUTES
  # an array of attributes that will be displayed on the model's index page.
  #
  # By default, it's limited to four items to reduce clutter on index pages.
  # Feel free to add, remove, or rearrange items.
  COLLECTION_ATTRIBUTES = %i[
    id
    deleted_at
    entity_attribute_values
    entity_sources
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
    deleted_at
    entity_attribute_values
    entity_sources
    entity_type
    incoming_relationships
    name
    outgoing_relationships
    project
    sources
    created_at
    updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
    deleted_at
    entity_attribute_values
    entity_sources
    entity_type
    incoming_relationships
    name
    outgoing_relationships
    project
    sources
  ].freeze

  # COLLECTION_FILTERS
  # a hash that defines filters that can be used while searching via the search
  # field of the dashboard.
  #
  # For example to add an option to search for open resources by typing "open:"
  # in the search field:
  #
  #   COLLECTION_FILTERS = {
  #     open: ->(resources) { resources.where(open: true) }
  #   }.freeze
  COLLECTION_FILTERS = {}.freeze

  # Overwrite this method to customize how entities are displayed
  # across all pages of the admin dashboard.
  #
  # def display_resource(entity)
  #   "Entity ##{entity.id}"
  # end
end
