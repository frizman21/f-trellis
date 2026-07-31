class Skill < ApplicationRecord
  has_many :skill_revisions, dependent: :destroy
  belongs_to :preferred_model, class_name: "Model", optional: true

  # `applicability` states which pages this skill is worth spending a call on.
  # It is read by the triage step, so an active skill without one cannot be
  # routed — hence the validation. A draft skill can be saved without it.
  validates :applicability, presence: true, if: :is_active?

  scope :promotable_pending, -> { where(is_promotable: true, is_fixtured: false) }

  # Skills triage can actually route: active, with a statement to route on, and
  # with a revision to run.
  scope :triageable, lambda {
    active_with_applicability = where(is_active: true)
                                 .where.not(applicability: nil)
                                 .where.not(applicability: "")
    active_with_applicability.where(id: SkillRevision.select(:skill_id))
  }
end
