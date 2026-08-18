class CreateContractParts < ActiveRecord::Migration[8.1]
  def change
    create_table :contract_parts do |t|
      t.references :contract, null: false, foreign_key: true
      t.references :part, null: false, foreign_key: true

      t.timestamps
    end

    add_index :contract_parts, [ :contract_id, :part_id ], unique: true,
              name: "index_cpt_on_pair"
  end
end
