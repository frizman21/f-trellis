class Technology < ApplicationRecord
  has_many :technology_details, dependent: :destroy

  has_many :part_technologies, dependent: :destroy
  has_many :parts, through: :part_technologies

  has_many :science_technologies, dependent: :destroy
  has_many :sciences, through: :science_technologies

  belongs_to :current_detail, class_name: "TechnologyDetail", optional: true
end
