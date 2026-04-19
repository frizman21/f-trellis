class CreatePartPartDetailPartPartTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :part_part_detail_part_part_types do |t|
      t.references :part_part_detail,
                   null: false,
                   foreign_key: true,
                   index: { name: "index_ppdppt_part_on_detail_id" }
      t.references :part_part_type,
                   null: false,
                   foreign_key: true,
                   index: { name: "index_ppdppt_part_on_type_id" }

      t.timestamps
    end

    add_index :part_part_detail_part_part_types,
              [ :part_part_detail_id, :part_part_type_id ],
              unique: true,
              name: "index_ppdppt_part_on_pair"
  end
end
