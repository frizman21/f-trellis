class AddRunStateToResearchStartingPoints < ActiveRecord::Migration[8.1]
  def change
    add_column :research_starting_points, :is_enabled,  :boolean,  null: false, default: true
    add_column :research_starting_points, :last_run_at, :datetime

    add_index :research_starting_points, :is_enabled
  end
end
