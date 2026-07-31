class SkillEvaluationModel < ApplicationRecord
  belongs_to :skill_evaluation
  belongs_to :model

  validates :model_id, uniqueness: { scope: :skill_evaluation_id }
end
