class PartPartType < ApplicationRecord
  has_many :part_part_detail_part_part_types, dependent: :destroy
  has_many :part_part_details, through: :part_part_detail_part_part_types
end
