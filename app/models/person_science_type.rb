class PersonScienceType < ApplicationRecord
  has_many :person_science_detail_person_science_types, dependent: :destroy
  has_many :person_science_details, through: :person_science_detail_person_science_types

  validates :name, presence: true, uniqueness: true
end
