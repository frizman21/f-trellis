class CreateContractPartDetails < ActiveRecord::Migration[8.1]
  def change
    create_table :contract_part_details do |t|
      t.references :contract_part, null: false, foreign_key: true,
                   index: { name: "index_cptd_on_contract_part_id" }
      t.references :source_processing_report, null: false, foreign_key: true,
                   index: { name: "index_cptd_on_source_processing_report_id" }
      t.datetime :as_of
      t.integer :confidence_tenths
      t.jsonb :additional_attributes, null: false, default: {}

      t.timestamps
    end
  end
end
