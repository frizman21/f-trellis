# One typed attribute every relationship of a type may carry.
class RelationshipTypeAttribute < ApplicationRecord
  include ScopedToProject
  include TypedAttribute

  belongs_to :relationship_type
  scoped_to_project_through :relationship_type

  has_many :relationship_type_values, dependent: :destroy

  validates :name, presence: true,
                   uniqueness: { scope: :relationship_type_id, case_sensitive: false }
end
