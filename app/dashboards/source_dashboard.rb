require "administrate/base_dashboard"

class SourceDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    child_sources: Field::HasMany,
    description: Field::Text,
    domain: Field::BelongsTo,
    entity_attribute_value_sources: Field::HasMany,
    entity_sources: Field::HasMany,
    etag: Field::String,
    inbound_links: Field::HasMany,
    is_fixtured: Field::Boolean,
    is_noindex: Field::Boolean,
    is_promotable: Field::Boolean,
    last_modified_at: Field::DateTime,
    learning_set_sources: Field::HasMany,
    learning_sets: Field::HasMany,
    linked_from: Field::HasMany,
    links_to: Field::HasMany,
    outbound_links: Field::HasMany,
    parent_source: Field::BelongsTo,
    project_sources: Field::HasMany,
    projects: Field::HasMany,
    relationship_sources: Field::HasMany,
    relationship_type_value_sources: Field::HasMany,
    resolved_url: Field::String,
    sitemap_lastmod_at: Field::DateTime,
    skill_evaluation_results: Field::HasMany,
    source_data: Field::HasMany,
    source_processing_reports: Field::HasMany,
    status: Field::String,
    url: Field::String,
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
    child_sources
    description
    domain
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
    child_sources
    description
    domain
    entity_attribute_value_sources
    entity_sources
    etag
    inbound_links
    is_fixtured
    is_noindex
    is_promotable
    last_modified_at
    learning_set_sources
    learning_sets
    linked_from
    links_to
    outbound_links
    parent_source
    project_sources
    projects
    relationship_sources
    relationship_type_value_sources
    resolved_url
    sitemap_lastmod_at
    skill_evaluation_results
    source_data
    source_processing_reports
    status
    url
    created_at
    updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
    child_sources
    description
    domain
    entity_attribute_value_sources
    entity_sources
    etag
    inbound_links
    is_fixtured
    is_noindex
    is_promotable
    last_modified_at
    learning_set_sources
    learning_sets
    linked_from
    links_to
    outbound_links
    parent_source
    project_sources
    projects
    relationship_sources
    relationship_type_value_sources
    resolved_url
    sitemap_lastmod_at
    skill_evaluation_results
    source_data
    source_processing_reports
    status
    url
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

  # Overwrite this method to customize how sources are displayed
  # across all pages of the admin dashboard.
  #
  # def display_resource(source)
  #   "Source ##{source.id}"
  # end
end
