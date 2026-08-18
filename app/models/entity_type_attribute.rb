# One typed attribute every entity of a type may carry.
#
# The column is `value_type`, not `type`: Rails reserves `type` for single-table
# inheritance and would try to instantiate a class named "int" on every load.
class EntityTypeAttribute < ApplicationRecord
  VALUE_TYPES = %w[int float string datetime].freeze

  # Which column on EntityAttributeValue a given declared type is stored in.
  VALUE_COLUMNS = {
    "int"      => :int_value,
    "float"    => :float_value,
    "string"   => :string_value,
    "datetime" => :datetime_value
  }.freeze

  include ScopedToProject

  belongs_to :entity_type
  scoped_to_project_through :entity_type

  has_many :entity_attribute_values, dependent: :destroy

  validates :name, presence: true,
                   uniqueness: { scope: :entity_type_id, case_sensitive: false }
  validates :value_type, inclusion: { in: VALUE_TYPES,
                                      message: "must be one of #{VALUE_TYPES.join(', ')}" }

  def value_column = VALUE_COLUMNS.fetch(value_type)
end
