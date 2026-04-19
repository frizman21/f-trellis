class PartDetail < ApplicationRecord
  belongs_to :part
  belongs_to :source_processing_report
  has_many :part_detail_part_types, dependent: :destroy
  has_many :part_types, through: :part_detail_part_types

  validates :name, presence: true
end
