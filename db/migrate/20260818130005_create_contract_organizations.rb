class CreateContractOrganizations < ActiveRecord::Migration[8.1]
  def change
    create_table :contract_organizations do |t|
      t.references :contract, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true

      t.timestamps
    end

    add_index :contract_organizations, [ :contract_id, :organization_id ], unique: true,
              name: "index_co_on_pair"
  end
end
