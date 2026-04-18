class PersonDetail < ApplicationRecord
  belongs_to :person
  has_many :person_detail_person_types, dependent: :destroy
  has_many :person_types, through: :person_detail_person_types
end
