class CreateTriageConfigurations < ActiveRecord::Migration[8.1]
  def change
    create_table :triage_configurations do |t|
      # Both nullable: an empty row must behave exactly like the hardcoded
      # service did, so the page can ship before anyone configures it and a
      # cleared field reads as a reset rather than a break.
      t.text :instructions
      t.references :model, foreign_key: true

      t.timestamps
    end
  end
end
