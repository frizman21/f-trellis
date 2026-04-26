class CreateResearchStartingPoints < ActiveRecord::Migration[8.1]
  def change
    create_table :research_starting_points do |t|
      t.string :url, null: false
      t.string :frequency, null: false
      t.text :description

      t.timestamps
    end

    add_index :research_starting_points, :frequency
  end
end
