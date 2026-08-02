# One performance metric a part type is measured by, and the unit it is measured
# in — weight in pounds, max power in watts.
#
# This is the schema, not a value: it says a Battery has a `capacity` in mAh, and
# PartDetailParameter says this battery's is 5000. Kept apart from
# `PartType#additional_attribute_keys`, which stays what it was — free-form
# labels like `manufacturer_part_number` that are strings and nothing more. The
# split is whether the thing is *measured*: a measurement is a number and a unit,
# and a property bag cannot hold that in a way anything can sort or compare.
class PartTypeParameter < ApplicationRecord
  # `number` carries a unit and lands in `value_number`; `text` is a stated spec
  # with no arithmetic in it ("IP67", "carbon fibre") and lands in `value_text`.
  VALUE_TYPES = %w[number text].freeze

  belongs_to :part_type
  has_many :part_detail_parameters, dependent: :destroy

  validates :name, presence: true,
                   uniqueness: { scope: :part_type_id, case_sensitive: false }
  validates :value_type, inclusion: { in: VALUE_TYPES }
  # A number without a unit is not a measurement — 12 what? Text parameters have
  # nothing to put here, so the rule applies only where it means something.
  validates :unit, presence: true, if: :number?

  normalizes :name, with: ->(value) { value.to_s.strip.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/\A_|_\z/, "") }
  normalizes :unit, with: ->(value) { value.to_s.strip.presence }

  scope :ordered, -> { order(:name) }

  def number? = value_type == "number"
  def text?   = value_type == "text"

  # "weight (lb)" — how the parameter is named wherever it is offered or shown.
  def label
    unit.present? ? "#{name} (#{unit})" : name
  end
end
