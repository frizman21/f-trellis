class PartTechnology < ApplicationRecord
  belongs_to :part
  belongs_to :technology
  belongs_to :current_detail, class_name: "PartTechnologyDetail", optional: true
  has_many :part_technology_details, dependent: :destroy
end
