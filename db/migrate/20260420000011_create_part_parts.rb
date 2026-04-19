class CreatePartParts < ActiveRecord::Migration[8.1]
  def change
    create_table :part_parts do |t|
      t.references :part_a, null: false, foreign_key: { to_table: :parts }
      t.references :part_b, null: false, foreign_key: { to_table: :parts }

      t.timestamps
    end

    add_index :part_parts, [ :part_a_id, :part_b_id ], unique: true
  end
end
