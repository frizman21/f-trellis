class ScienceTechnologyDetail < ApplicationRecord
  belongs_to :science_technology
  belongs_to :source_processing_report
  has_many :science_technology_detail_science_technology_types, dependent: :destroy
  has_many :science_technology_types,
           through: :science_technology_detail_science_technology_types
end
