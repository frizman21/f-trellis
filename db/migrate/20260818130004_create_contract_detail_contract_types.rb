# Index names given explicitly: the conventional ones run past Postgres'
# 63-character identifier limit. See docs/data-model-spec.md §4.
class CreateContractDetailContractTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :contract_detail_contract_types do |t|
      t.references :contract_detail, null: false, foreign_key: true,
                   index: { name: "index_cdct_on_detail_id" }
      t.references :contract_type,   null: false, foreign_key: true,
                   index: { name: "index_cdct_on_type_id" }

      t.timestamps
    end

    add_index :contract_detail_contract_types,
              [ :contract_detail_id, :contract_type_id ],
              unique: true,
              name: "index_cdct_on_detail_and_type"
  end
end
