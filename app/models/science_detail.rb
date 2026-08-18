class ScienceDetail < ApplicationRecord
  belongs_to :science
  belongs_to :source_processing_report
  has_many :science_detail_science_types, dependent: :destroy
  has_many :science_types, through: :science_detail_science_types

  validates :name, presence: true
end
