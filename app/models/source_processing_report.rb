class SourceProcessingReport < ApplicationRecord
  belongs_to :source
  belongs_to :skill_revision
end
