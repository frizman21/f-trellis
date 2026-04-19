class Person < ApplicationRecord
  has_many :person_details, dependent: :destroy
  has_many :person_organizations, dependent: :destroy
  has_many :organizations, through: :person_organizations

  has_many :person_people_as_a,
           class_name: "PersonPerson",
           foreign_key: :person_a_id,
           dependent: :destroy,
           inverse_of: :person_a
  has_many :person_people_as_b,
           class_name: "PersonPerson",
           foreign_key: :person_b_id,
           dependent: :destroy,
           inverse_of: :person_b

  belongs_to :current_detail, class_name: "PersonDetail", optional: true

  # All PersonPerson rows where this person sits on either side.
  def person_people
    PersonPerson.where("person_a_id = :id OR person_b_id = :id", id: id)
  end
end
