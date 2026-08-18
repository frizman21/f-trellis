# Index names given explicitly: the conventional ones run past Postgres'
# 63-character identifier limit. `cpsdcpst` rather than the obvious `psdpst`,
# which person_science already holds — index names are database-wide.
class CreateContractPersonDetailContractPersonTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :contract_person_detail_contract_person_types do |t|
      t.references :contract_person_detail,
                   null: false,
                   foreign_key: true,
                   index: { name: "index_cpsdcpst_on_detail_id" }
      t.references :contract_person_type,
                   null: false,
                   foreign_key: true,
                   index: { name: "index_cpsdcpst_on_type_id" }

      t.timestamps
    end

    add_index :contract_person_detail_contract_person_types,
              [ :contract_person_detail_id, :contract_person_type_id ],
              unique: true,
              name: "index_cpsdcpst_on_pair"
  end
end
