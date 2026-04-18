class Person < ApplicationRecord
  has_many :person_details, dependent: :destroy
end
