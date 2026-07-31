class AddApplicabilityToSkills < ActiveRecord::Migration[8.1]
  def change
    add_column :skills, :applicability, :text
  end
end
