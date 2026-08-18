class CreatePersonSciences < ActiveRecord::Migration[8.1]
  def change
    create_table :person_sciences do |t|
      t.references :person,  null: false, foreign_key: true
      t.references :science, null: false, foreign_key: true

      t.timestamps
    end

    add_index :person_sciences, [ :person_id, :science_id ], unique: true
  end
end
