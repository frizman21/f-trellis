class SkillRevision < ApplicationRecord
  belongs_to :skill
  has_many :source_processing_reports, dependent: :destroy
end
