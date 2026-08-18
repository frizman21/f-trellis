# One typed attribute every entity of a type may carry.
#
# The column is `value_type`, not `type`: Rails reserves `type` for single-table
# inheritance and would try to instantiate a class named "int" on every load.
class EntityTypeAttribute < ApplicationRecord
  include ScopedToProject
  include TypedAttribute

  belongs_to :entity_type
  scoped_to_project_through :entity_type

  has_many :entity_attribute_values, dependent: :restrict_with_error

  # What TypedAttribute#used? asks.
  alias_method :recorded_values, :entity_attribute_values

  validates :name, presence: true,
                   uniqueness: { scope: :entity_type_id, case_sensitive: false }
end
