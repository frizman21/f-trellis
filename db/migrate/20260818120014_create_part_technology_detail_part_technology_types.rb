# The conventional index names for this join run past Postgres' 63-character
# identifier limit, so every one of them is named explicitly. See the
# `org_org_typings` note in docs/data-model-spec.md §4.
class CreatePartTechnologyDetailPartTechnologyTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :part_technology_detail_part_technology_types do |t|
      t.references :part_technology_detail,
                   null: false,
                   foreign_key: true,
                   index: { name: "index_ptdptt_on_detail_id" }
      t.references :part_technology_type,
                   null: false,
                   foreign_key: true,
                   index: { name: "index_ptdptt_on_type_id" }

      t.timestamps
    end

    add_index :part_technology_detail_part_technology_types,
              [ :part_technology_detail_id, :part_technology_type_id ],
              unique: true,
              name: "index_ptdptt_on_pair"
  end
end
