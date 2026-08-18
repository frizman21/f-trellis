# Index names given explicitly: the conventional ones run past Postgres'
# 63-character identifier limit. See docs/data-model-spec.md §4.
class CreateContractOrganizationDetailContractOrganizationTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :contract_organization_detail_contract_organization_types do |t|
      t.references :contract_organization_detail,
                   null: false,
                   foreign_key: true,
                   index: { name: "index_codcot_on_detail_id" }
      t.references :contract_organization_type,
                   null: false,
                   foreign_key: true,
                   index: { name: "index_codcot_on_type_id" }

      t.timestamps
    end

    add_index :contract_organization_detail_contract_organization_types,
              [ :contract_organization_detail_id, :contract_organization_type_id ],
              unique: true,
              name: "index_codcot_on_pair"
  end
end
