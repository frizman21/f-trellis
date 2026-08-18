# Index names given explicitly — see
# CreatePartTechnologyDetailPartTechnologyTypes.
class CreateScienceTechnologyDetailScienceTechnologyTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :science_technology_detail_science_technology_types do |t|
      t.references :science_technology_detail,
                   null: false,
                   foreign_key: true,
                   index: { name: "index_stdstt_on_detail_id" }
      t.references :science_technology_type,
                   null: false,
                   foreign_key: true,
                   index: { name: "index_stdstt_on_type_id" }

      t.timestamps
    end

    add_index :science_technology_detail_science_technology_types,
              [ :science_technology_detail_id, :science_technology_type_id ],
              unique: true,
              name: "index_stdstt_on_pair"
  end
end
