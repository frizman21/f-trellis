class CreateOrganizationOrganizations < ActiveRecord::Migration[8.1]
  def change
    create_table :organization_organizations do |t|
      t.references :organization_a, null: false, foreign_key: { to_table: :organizations }
      t.references :organization_b, null: false, foreign_key: { to_table: :organizations }

      t.timestamps
    end

    add_index :organization_organizations,
              [ :organization_a_id, :organization_b_id ],
              unique: true,
              name: "index_org_orgs_on_a_and_b"
  end
end
