class TechnologyType < ApplicationRecord
  has_many :technology_detail_technology_types, dependent: :destroy
  has_many :technology_details, through: :technology_detail_technology_types

  validates :name, presence: true, uniqueness: true
end
