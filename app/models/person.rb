class Person < ApplicationRecord
  has_many :person_details, dependent: :destroy
  belongs_to :current_detail, class_name: "PersonDetail", optional: true
end
