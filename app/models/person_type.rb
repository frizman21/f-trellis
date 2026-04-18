class PersonType < ApplicationRecord
  has_many :person_detail_person_types, dependent: :destroy
  has_many :person_details, through: :person_detail_person_types
end
