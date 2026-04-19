class CreatePartOrganizationDetailPartOrganizationTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :part_organization_detail_part_organization_types do |t|
      t.references :part_organization_detail,
                   null: false,
                   foreign_key: true,
                   index: { name: "index_podpot_part_on_detail_id" }
      t.references :part_organization_type,
                   null: false,
                   foreign_key: true,
                   index: { name: "index_podpot_part_on_type_id" }

      t.timestamps
    end

    add_index :part_organization_detail_part_organization_types,
              [ :part_organization_detail_id, :part_organization_type_id ],
              unique: true,
              name: "index_podpot_part_on_pair"
  end
end
