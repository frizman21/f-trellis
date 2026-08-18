class PersonScience < ApplicationRecord
  belongs_to :person
  belongs_to :science
  belongs_to :current_detail, class_name: "PersonScienceDetail", optional: true
  has_many :person_science_details, dependent: :destroy
end
