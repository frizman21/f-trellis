class PersonPersonDetail < ApplicationRecord
  belongs_to :person_person
  belongs_to :source_processing_report
  has_many :person_person_detail_person_person_types, dependent: :destroy
  has_many :person_person_types, through: :person_person_detail_person_person_types
end
