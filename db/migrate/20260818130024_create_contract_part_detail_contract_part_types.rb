# Index names given explicitly: the conventional ones run past Postgres'
# 63-character identifier limit. `cptdcptt` rather than `ptdptt`, which
# part_technology already holds — index names are database-wide.
class CreateContractPartDetailContractPartTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :contract_part_detail_contract_part_types do |t|
      t.references :contract_part_detail,
                   null: false,
                   foreign_key: true,
                   index: { name: "index_cptdcptt_on_detail_id" }
      t.references :contract_part_type,
                   null: false,
                   foreign_key: true,
                   index: { name: "index_cptdcptt_on_type_id" }

      t.timestamps
    end

    add_index :contract_part_detail_contract_part_types,
              [ :contract_part_detail_id, :contract_part_type_id ],
              unique: true,
              name: "index_cptdcptt_on_pair"
  end
end
