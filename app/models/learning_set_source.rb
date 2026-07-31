class LearningSetSource < ApplicationRecord
  belongs_to :learning_set
  belongs_to :source

  validates :source_id, uniqueness: { scope: :learning_set_id }
end
