class CreateContractTechnologies < ActiveRecord::Migration[8.1]
  def change
    create_table :contract_technologies do |t|
      t.references :contract, null: false, foreign_key: true
      t.references :technology, null: false, foreign_key: true

      t.timestamps
    end

    add_index :contract_technologies, [ :contract_id, :technology_id ], unique: true,
              name: "index_ct_on_pair"
  end
end
