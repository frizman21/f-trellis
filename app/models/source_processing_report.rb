class SourceProcessingReport < ApplicationRecord
  belongs_to :source
  belongs_to :skill_revision
  has_many :person_details, dependent: :destroy
end
