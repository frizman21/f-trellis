class ScienceTechnologyType < ApplicationRecord
  has_many :science_technology_detail_science_technology_types, dependent: :destroy
  has_many :science_technology_details,
           through: :science_technology_detail_science_technology_types

  validates :name, presence: true, uniqueness: true
end
