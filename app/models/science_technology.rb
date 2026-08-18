class ScienceTechnology < ApplicationRecord
  belongs_to :science
  belongs_to :technology
  belongs_to :current_detail, class_name: "ScienceTechnologyDetail", optional: true
  has_many :science_technology_details, dependent: :destroy
end
