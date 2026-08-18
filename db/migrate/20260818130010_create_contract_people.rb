class CreateContractPeople < ActiveRecord::Migration[8.1]
  def change
    create_table :contract_people do |t|
      t.references :contract, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true

      t.timestamps
    end

    add_index :contract_people, [ :contract_id, :person_id ], unique: true,
              name: "index_cps_on_pair"
  end
end
