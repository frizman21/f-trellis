class PartPartDetail < ApplicationRecord
  belongs_to :part_part
  belongs_to :source_processing_report
  has_many :part_part_detail_part_part_types, dependent: :destroy
  has_many :part_part_types, through: :part_part_detail_part_part_types
end
