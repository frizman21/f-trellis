class Skill < ApplicationRecord
  has_many :skill_revisions, dependent: :destroy
  belongs_to :preferred_model, class_name: "Model", optional: true

  scope :promotable_pending, -> { where(is_promotable: true, is_fixtured: false) }
end
