class PartTechnologyDetail < ApplicationRecord
  belongs_to :part_technology
  belongs_to :source_processing_report
  has_many :part_technology_detail_part_technology_types, dependent: :destroy
  has_many :part_technology_types, through: :part_technology_detail_part_technology_types
end
