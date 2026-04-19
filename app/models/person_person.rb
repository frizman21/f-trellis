class PersonPerson < ApplicationRecord
  belongs_to :person_a, class_name: "Person"
  belongs_to :person_b, class_name: "Person"
  belongs_to :current_detail, class_name: "PersonPersonDetail", optional: true
  has_many :person_person_details, dependent: :destroy

  # Returns the "other" Person on this edge given one of the endpoints.
  def other_person(person)
    person_a_id == person.id ? person_b : person_a
  end
end
