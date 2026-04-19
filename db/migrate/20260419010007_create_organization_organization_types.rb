class CreateOrganizationOrganizationTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :organization_organization_types do |t|
      t.string :name, null: false
      t.text :description
      t.text :additional_attribute_keys, array: true, null: false, default: []

      t.timestamps
    end

    add_index :organization_organization_types, :name, unique: true, name: "index_org_org_types_on_name"
  end
end
