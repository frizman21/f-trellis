require "administrate/base_dashboard"

class ModelDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    capabilities: Field::String.with_options(searchable: false),
    chats: Field::HasMany,
    context_window: Field::Number,
    family: Field::String,
    is_deprecated: Field::Boolean,
    is_disabled: Field::Boolean,
    knowledge_cutoff: Field::Date,
    last_seen_at: Field::DateTime,
    max_output_tokens: Field::Number,
    metadata: Field::String.with_options(searchable: false),
    modalities: Field::String.with_options(searchable: false),
    model_created_at: Field::DateTime,
    model_endpoint: Field::BelongsTo,
    model_id: Field::String,
    name: Field::String,
    pricing: Field::String.with_options(searchable: false),
    provider: Field::String,
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
    capabilities
    chats
    context_window
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
    capabilities
    chats
    context_window
    family
    is_deprecated
    is_disabled
    knowledge_cutoff
    last_seen_at
    max_output_tokens
    metadata
    modalities
    model_created_at
    model_endpoint
    model_id
    name
    pricing
    provider
    created_at
    updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
    capabilities
    chats
    context_window
    family
    is_deprecated
    is_disabled
    knowledge_cutoff
    last_seen_at
    max_output_tokens
    metadata
    modalities
    model_created_at
    model_endpoint
    model_id
    name
    pricing
    provider
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

  # Overwrite this method to customize how models are displayed
  # across all pages of the admin dashboard.
  #
  # def display_resource(model)
  #   "Model ##{model.id}"
  # end
end
