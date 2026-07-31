class AddModelObjectiveToSkillEvaluations < ActiveRecord::Migration[8.0]
  def change
    # Which objective produced the model set, or NULL for a hand-picked one.
    # Provenance only — nothing reads it to re-derive the set, because the set
    # itself is stored and the registry underneath it moves.
    add_column :skill_evaluations, :model_objective, :string
  end
end
