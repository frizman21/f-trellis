class FacilityType < ApplicationRecord
  has_many :facility_detail_facility_types, dependent: :destroy
  has_many :facility_details, through: :facility_detail_facility_types
end
