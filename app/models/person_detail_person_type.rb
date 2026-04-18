class PersonDetailPersonType < ApplicationRecord
  belongs_to :person_detail
  belongs_to :person_type
end
