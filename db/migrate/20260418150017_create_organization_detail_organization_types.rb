class CreateOrganizationDetailOrganizationTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :organization_detail_organization_types do |t|
      t.references :organization_detail, null: false, foreign_key: true
      t.references :organization_type,   null: false, foreign_key: true

      t.timestamps
    end

    add_index :organization_detail_organization_types,
              [ :organization_detail_id, :organization_type_id ],
              unique: true,
              name: "index_odot_on_detail_and_type"
  end
end
