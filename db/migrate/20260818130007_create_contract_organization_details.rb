class CreateContractOrganizationDetails < ActiveRecord::Migration[8.1]
  def change
    create_table :contract_organization_details do |t|
      t.references :contract_organization, null: false, foreign_key: true,
                   index: { name: "index_cod_on_contract_organization_id" }
      t.references :source_processing_report, null: false, foreign_key: true,
                   index: { name: "index_cod_on_source_processing_report_id" }
      t.datetime :as_of
      t.integer :confidence_tenths
      t.jsonb :additional_attributes, null: false, default: {}

      t.timestamps
    end
  end
end
