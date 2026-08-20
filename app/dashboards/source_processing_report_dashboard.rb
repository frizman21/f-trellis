require "administrate/base_dashboard"

class SourceProcessingReportDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    chat: Field::BelongsTo,
    content_hash: Field::String,
    contract_details: Field::HasMany,
    contract_organization_details: Field::HasMany,
    contract_part_details: Field::HasMany,
    contract_person_details: Field::HasMany,
    contract_technology_details: Field::HasMany,
    error: Field::Text,
    facility_details: Field::HasMany,
    facts: Field::String.with_options(searchable: false),
    model: Field::BelongsTo,
    organization_details: Field::HasMany,
    organization_organization_details: Field::HasMany,
    organization_technology_details: Field::HasMany,
    part_details: Field::HasMany,
    part_organization_details: Field::HasMany,
    part_part_details: Field::HasMany,
    part_technology_details: Field::HasMany,
    person_details: Field::HasMany,
    person_organization_details: Field::HasMany,
    person_person_details: Field::HasMany,
    person_science_details: Field::HasMany,
    science_details: Field::HasMany,
    science_technology_details: Field::HasMany,
    skill_revision: Field::BelongsTo,
    source: Field::BelongsTo,
    status: Field::String,
    technology_details: Field::HasMany,
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
    chat
    content_hash
    contract_details
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
    chat
    content_hash
    contract_details
    contract_organization_details
    contract_part_details
    contract_person_details
    contract_technology_details
    error
    facility_details
    facts
    model
    organization_details
    organization_organization_details
    organization_technology_details
    part_details
    part_organization_details
    part_part_details
    part_technology_details
    person_details
    person_organization_details
    person_person_details
    person_science_details
    science_details
    science_technology_details
    skill_revision
    source
    status
    technology_details
    created_at
    updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
    chat
    content_hash
    contract_details
    contract_organization_details
    contract_part_details
    contract_person_details
    contract_technology_details
    error
    facility_details
    facts
    model
    organization_details
    organization_organization_details
    organization_technology_details
    part_details
    part_organization_details
    part_part_details
    part_technology_details
    person_details
    person_organization_details
    person_person_details
    person_science_details
    science_details
    science_technology_details
    skill_revision
    source
    status
    technology_details
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

  # Overwrite this method to customize how source processing reports are displayed
  # across all pages of the admin dashboard.
  #
  # def display_resource(source_processing_report)
  #   "SourceProcessingReport ##{source_processing_report.id}"
  # end
end
