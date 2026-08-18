class CreateOrganizationTechnologies < ActiveRecord::Migration[8.1]
  def change
    create_table :organization_technologies do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :technology, null: false, foreign_key: true

      t.timestamps
    end

    add_index :organization_technologies, [ :organization_id, :technology_id ], unique: true,
              name: "index_ot_on_pair"
  end
end
