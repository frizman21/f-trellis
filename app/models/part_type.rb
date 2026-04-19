class PartType < ApplicationRecord
  has_many :part_detail_part_types, dependent: :destroy
  has_many :part_details, through: :part_detail_part_types
end
