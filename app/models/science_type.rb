class ScienceType < ApplicationRecord
  has_many :science_detail_science_types, dependent: :destroy
  has_many :science_details, through: :science_detail_science_types

  validates :name, presence: true, uniqueness: true
end
