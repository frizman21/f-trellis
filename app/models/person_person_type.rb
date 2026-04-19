class PersonPersonType < ApplicationRecord
  has_many :person_person_detail_person_person_types, dependent: :destroy
  has_many :person_person_details, through: :person_person_detail_person_person_types
end
