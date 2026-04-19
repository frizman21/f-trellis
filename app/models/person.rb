class Person < ApplicationRecord
  has_many :person_details, dependent: :destroy
  has_many :person_organizations, dependent: :destroy
  has_many :organizations, through: :person_organizations
  belongs_to :current_detail, class_name: "PersonDetail", optional: true
end
