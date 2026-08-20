require "administrate/base_dashboard"

class MessageDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    attachments_attachments: Field::HasMany,
    attachments_blobs: Field::HasMany,
    cache_creation_tokens: Field::Number,
    cached_tokens: Field::Number,
    chat: Field::BelongsTo,
    content: Field::Text,
    content_raw: Field::String.with_options(searchable: false),
    input_tokens: Field::Number,
    model: Field::BelongsTo,
    output_tokens: Field::Number,
    parent_tool_call: Field::BelongsTo,
    role: Field::String,
    thinking_signature: Field::Text,
    thinking_text: Field::Text,
    thinking_tokens: Field::Number,
    tool_call_id: Field::Number,
    tool_calls: Field::HasMany,
    tool_results: Field::HasMany,
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
    attachments_attachments
    attachments_blobs
    cache_creation_tokens
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
    attachments_attachments
    attachments_blobs
    cache_creation_tokens
    cached_tokens
    chat
    content
    content_raw
    input_tokens
    model
    output_tokens
    parent_tool_call
    role
    thinking_signature
    thinking_text
    thinking_tokens
    tool_call_id
    tool_calls
    tool_results
    created_at
    updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
    attachments_attachments
    attachments_blobs
    cache_creation_tokens
    cached_tokens
    chat
    content
    content_raw
    input_tokens
    model
    output_tokens
    parent_tool_call
    role
    thinking_signature
    thinking_text
    thinking_tokens
    tool_call_id
    tool_calls
    tool_results
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

  # Overwrite this method to customize how messages are displayed
  # across all pages of the admin dashboard.
  #
  # def display_resource(message)
  #   "Message ##{message.id}"
  # end
end
