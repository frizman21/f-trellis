class CreateOrganizationTechnologyDetails < ActiveRecord::Migration[8.1]
  def change
    create_table :organization_technology_details do |t|
      t.references :organization_technology, null: false, foreign_key: true,
                   index: { name: "index_otd_on_organization_technology_id" }
      t.references :source_processing_report, null: false, foreign_key: true,
                   index: { name: "index_otd_on_source_processing_report_id" }
      t.datetime :as_of
      t.integer :confidence_tenths
      t.jsonb :additional_attributes, null: false, default: {}

      t.timestamps
    end
  end
end
