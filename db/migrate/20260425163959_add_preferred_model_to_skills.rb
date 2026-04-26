class AddPreferredModelToSkills < ActiveRecord::Migration[8.1]
  def up
    add_reference :skills, :preferred_model, foreign_key: { to_table: :models }

    Skill.reset_column_information
    cheap_default = Model.find_by(provider: "openai", model_id: "gpt-5-nano")
    Skill.update_all(preferred_model_id: cheap_default.id) if cheap_default
  end

  def down
    remove_reference :skills, :preferred_model, foreign_key: { to_table: :models }
  end
end
