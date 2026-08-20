# One recorded value for one attribute of one entity.
class EntityAttributeValue < ApplicationRecord
  include ScopedToProject
  include TypedValue

  belongs_to :entity
  scoped_to_project_through :entity

  belongs_to :entity_type_attribute

  has_many :entity_attribute_value_extraction_runs, dependent: :destroy
  has_many :sources, through: :entity_attribute_value_extraction_runs

  accepts_nested_attributes_for :entity_attribute_value_extraction_runs, reject_if: ->(attrs) { attrs["source_id"].blank? }

  validates :entity_type_attribute_id, uniqueness: { scope: :entity_id }

  # What TypedValue needs to know which column is live.
  alias_method :typed_attribute, :entity_type_attribute
end
