# One measured value on one PartDetail: this drone's weight is 1.375, in the
# pounds the parameter declares.
#
# Not a Detail of its own. It is part of the assertion the PartDetail makes, so
# it inherits that row's `as_of` and its `source_processing_report` rather than
# carrying duplicates. Re-processing a page writes a new PartDetail with a fresh
# set of these, which is how details stay append-only.
class PartDetailParameter < ApplicationRecord
  belongs_to :part_detail
  belongs_to :part_type_parameter

  validates :part_type_parameter_id, uniqueness: { scope: :part_detail_id }
  validate :value_matches_the_parameter_type

  delegate :name, :unit, :value_type, :number?, :text?, to: :part_type_parameter

  scope :ordered, -> { joins(:part_type_parameter).order("part_type_parameters.name") }

  # The value in the parameter's own terms, whichever column holds it.
  def value
    number? ? value_number : value_text
  end

  # "1.375 lb", or the text value as given. Trailing zeros dropped — the column
  # stores six decimal places so grams and tonnes both fit, not because a weight
  # should read as "1.375000".
  def to_s
    return value_text.to_s unless number?
    return "" if value_number.nil?

    [ format("%g", value_number), unit ].compact_blank.join(" ")
  end

  # True when the page stated this in different terms from the ones it is stored
  # in — worth showing, because a conversion is where an extraction goes wrong
  # quietly.
  def converted?
    as_stated.present? && as_stated.strip != to_s
  end

  private

  def value_matches_the_parameter_type
    return if part_type_parameter.nil?

    if number? && value_number.nil?
      errors.add(:value_number, "is required for #{name}, which is measured in #{unit}")
    elsif text? && value_text.blank?
      errors.add(:value_text, "is required for #{name}")
    end
  end
end
