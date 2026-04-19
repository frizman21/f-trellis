class FacilityDetail < ApplicationRecord
  belongs_to :facility
  belongs_to :source_processing_report
  has_many :facility_detail_facility_types, dependent: :destroy
  has_many :facility_types, through: :facility_detail_facility_types

  validates :address, presence: true
end
