class CreatePartDetailPartTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :part_detail_part_types do |t|
      t.references :part_detail, null: false, foreign_key: true
      t.references :part_type,   null: false, foreign_key: true

      t.timestamps
    end

    add_index :part_detail_part_types,
              [ :part_detail_id, :part_type_id ],
              unique: true,
              name: "index_pdpt_part_on_detail_and_type"
  end
end
