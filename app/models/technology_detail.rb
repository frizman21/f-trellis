class TechnologyDetail < ApplicationRecord
  belongs_to :technology
  belongs_to :source_processing_report
  has_many :technology_detail_technology_types, dependent: :destroy
  has_many :technology_types, through: :technology_detail_technology_types

  validates :name, presence: true
end
