class Facility < ApplicationRecord
  has_many :facility_details, dependent: :destroy
  belongs_to :current_detail, class_name: "FacilityDetail", optional: true
end
