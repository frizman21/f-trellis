class CreateOoDetailOoTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :org_org_typings do |t|
      t.references :organization_organization_detail,
                   null: false,
                   foreign_key: true,
                   index: { name: "index_org_org_typings_on_detail_id" }
      t.references :organization_organization_type,
                   null: false,
                   foreign_key: true,
                   index: { name: "index_org_org_typings_on_type_id" }

      t.timestamps
    end

    add_index :org_org_typings,
              [ :organization_organization_detail_id, :organization_organization_type_id ],
              unique: true,
              name: "index_org_org_typings_on_pair"
  end
end
