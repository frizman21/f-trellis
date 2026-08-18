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

    # What the forms and the type popover read: what this type tracks now.
    scope :active, -> { where(is_disabled: false) }

    # The columns a type's list shows. Composed with `active` rather than read
    # alone: an attribute no longer tracked is not a column, whatever the flag
    # says, and the two flags answer different questions.
    scope :displayed_on_index, -> { active.where(is_displayed_on_index: true) }
  end

  # Whether anything has ever been recorded against this attribute. Deleting one
  # that has been used would delete those values, so the UI offers Disable
  # instead and the association below refuses the deletion either way.
  def used? = recorded_values.exists?

  def value_column = VALUE_COLUMNS.fetch(value_type)

  def enabled? = !is_disabled?
end
