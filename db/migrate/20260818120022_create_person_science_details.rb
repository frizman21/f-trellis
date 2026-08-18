class CreatePersonScienceDetails < ActiveRecord::Migration[8.1]
  def change
    create_table :person_science_details do |t|
      t.references :person_science,           null: false, foreign_key: true
      t.references :source_processing_report, null: false, foreign_key: true,
                   index: { name: "index_psd_on_source_processing_report_id" }
      t.datetime :as_of
      t.integer :confidence_tenths
      t.jsonb :additional_attributes, null: false, default: {}

      t.timestamps
    end
  end
end
