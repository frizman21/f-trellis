class CreatePartTechnologies < ActiveRecord::Migration[8.1]
  def change
    create_table :part_technologies do |t|
      t.references :part,       null: false, foreign_key: true
      t.references :technology, null: false, foreign_key: true

      t.timestamps
    end

    add_index :part_technologies, [ :part_id, :technology_id ], unique: true
  end
end
