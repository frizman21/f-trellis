class PartType < ApplicationRecord
  has_many :part_detail_part_types, dependent: :destroy
  has_many :part_details, through: :part_detail_part_types
  # The performance metrics parts of this type are measured by. See
  # PartTypeParameter for why these are rows rather than more entries in
  # `additional_attribute_keys`.
  has_many :part_type_parameters, -> { ordered }, dependent: :destroy, inverse_of: :part_type

  accepts_nested_attributes_for :part_type_parameters, allow_destroy: true,
                                reject_if: ->(attrs) { attrs["name"].blank? }
end
