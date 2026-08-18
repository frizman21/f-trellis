# One recorded value for one attribute of one entity.
class EntityAttributeValue < ApplicationRecord
  include ScopedToProject
  include TypedValue

  belongs_to :entity
  scoped_to_project_through :entity

  belongs_to :entity_type_attribute

  validates :entity_type_attribute_id, uniqueness: { scope: :entity_id }

  # What TypedValue needs to know which column is live.
  alias_method :typed_attribute, :entity_type_attribute
end
