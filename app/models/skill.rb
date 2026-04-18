class Skill < ApplicationRecord
  has_many :skill_revisions, dependent: :destroy
end
