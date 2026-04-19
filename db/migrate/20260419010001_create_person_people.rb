class CreatePersonPeople < ActiveRecord::Migration[8.1]
  def change
    create_table :person_people do |t|
      t.references :person_a, null: false, foreign_key: { to_table: :people }
      t.references :person_b, null: false, foreign_key: { to_table: :people }

      t.timestamps
    end

    add_index :person_people, [ :person_a_id, :person_b_id ], unique: true
  end
end
