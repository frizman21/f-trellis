class CreateTechnologyDetailTechnologyTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :technology_detail_technology_types do |t|
      t.references :technology_detail, null: false, foreign_key: true,
                   index: { name: "index_tdtt_on_detail_id" }
      t.references :technology_type,   null: false, foreign_key: true,
                   index: { name: "index_tdtt_on_type_id" }

      t.timestamps
    end

    add_index :technology_detail_technology_types,
              [ :technology_detail_id, :technology_type_id ],
              unique: true,
              name: "index_tdtt_on_detail_and_type"
  end
end
