class CreatePartOrganizations < ActiveRecord::Migration[8.1]
  def change
    create_table :part_organizations do |t|
      t.references :part,         null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true

      t.timestamps
    end

    add_index :part_organizations, [ :part_id, :organization_id ], unique: true
  end
end
