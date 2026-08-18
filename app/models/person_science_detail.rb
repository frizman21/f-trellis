class PersonScienceDetail < ApplicationRecord
  belongs_to :person_science
  belongs_to :source_processing_report
  has_many :person_science_detail_person_science_types, dependent: :destroy
  has_many :person_science_types, through: :person_science_detail_person_science_types
end
