# One recorded value for one attribute of one relationship.
class RelationshipTypeValue < ApplicationRecord
  include ScopedToProject
  include TypedValue

  belongs_to :relationship
  scoped_to_project_through :relationship

  belongs_to :relationship_type_attribute

  validates :relationship_type_attribute_id, uniqueness: { scope: :relationship_id }

  # What TypedValue needs to know which column is live.
  alias_method :typed_attribute, :relationship_type_attribute
end
