class AddModelToSkillRevisions < ActiveRecord::Migration[8.1]
  def change
    # Nullable, and deliberately not backfilled: the skill's current
    # preferred_model was not necessarily in force when an older revision was
    # written, so filling it in would assert a history nobody recorded. Null
    # reads as "not recorded", and the queueing path falls back to the skill.
    add_reference :skill_revisions, :model, null: true, foreign_key: true
  end
end
