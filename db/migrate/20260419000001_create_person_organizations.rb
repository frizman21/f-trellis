class CreatePersonOrganizations < ActiveRecord::Migration[8.1]
  def change
    create_table :person_organizations do |t|
      t.references :person,       null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true

      t.timestamps
    end

    add_index :person_organizations, [ :person_id, :organization_id ], unique: true
  end
end
