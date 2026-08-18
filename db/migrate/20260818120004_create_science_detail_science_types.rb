class CreateScienceDetailScienceTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :science_detail_science_types do |t|
      t.references :science_detail, null: false, foreign_key: true
      t.references :science_type,   null: false, foreign_key: true

      t.timestamps
    end

    add_index :science_detail_science_types,
              [ :science_detail_id, :science_type_id ],
              unique: true,
              name: "index_sdst_on_detail_and_type"
  end
end
