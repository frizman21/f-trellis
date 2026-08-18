# The declaration half of a typed attribute: which value types are permitted,
# and which column each one is stored in.
#
# Shared by EntityTypeAttribute and RelationshipTypeAttribute. The alternative
# was a second copy of the enumeration and its column mapping, and two copies of
# a rule like "these are the four permitted types" drift.
module TypedAttribute
  extend ActiveSupport::Concern

  VALUE_TYPES = %w[int float string datetime].freeze

  # Which column on the matching value table a given declared type is stored in.
  VALUE_COLUMNS = {
    "int"      => :int_value,
    "float"    => :float_value,
    "string"   => :string_value,
    "datetime" => :datetime_value
  }.freeze

  included do
    validates :value_type, inclusion: { in: VALUE_TYPES,
                                        message: "must be one of #{VALUE_TYPES.join(', ')}" }
  end

  def value_column = VALUE_COLUMNS.fetch(value_type)
end
