# Index names given explicitly: the conventional ones run past Postgres'
# 63-character identifier limit. See docs/data-model-spec.md §4.
class CreateContractTechnologyDetailContractTechnologyTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :contract_technology_detail_contract_technology_types do |t|
      t.references :contract_technology_detail,
                   null: false,
                   foreign_key: true,
                   index: { name: "index_ctdctt_on_detail_id" }
      t.references :contract_technology_type,
                   null: false,
                   foreign_key: true,
                   index: { name: "index_ctdctt_on_type_id" }

      t.timestamps
    end

    add_index :contract_technology_detail_contract_technology_types,
              [ :contract_technology_detail_id, :contract_technology_type_id ],
              unique: true,
              name: "index_ctdctt_on_pair"
  end
end
