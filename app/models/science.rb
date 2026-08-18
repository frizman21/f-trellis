class Science < ApplicationRecord
  has_many :science_details, dependent: :destroy

  has_many :person_sciences, dependent: :destroy
  has_many :people, through: :person_sciences

  has_many :science_technologies, dependent: :destroy
  has_many :technologies, through: :science_technologies

  belongs_to :current_detail, class_name: "ScienceDetail", optional: true
end
