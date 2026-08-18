class CreateScienceTechnologies < ActiveRecord::Migration[8.1]
  def change
    create_table :science_technologies do |t|
      t.references :science,    null: false, foreign_key: true
      t.references :technology, null: false, foreign_key: true

      t.timestamps
    end

    add_index :science_technologies, [ :science_id, :technology_id ], unique: true
  end
end
