class PartTechnologyType < ApplicationRecord
  has_many :part_technology_detail_part_technology_types, dependent: :destroy
  has_many :part_technology_details, through: :part_technology_detail_part_technology_types

  validates :name, presence: true, uniqueness: true
end
