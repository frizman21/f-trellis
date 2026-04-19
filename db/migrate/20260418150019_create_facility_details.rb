class CreateFacilityDetails < ActiveRecord::Migration[8.1]
  def change
    create_table :facility_details do |t|
      t.references :facility, null: false, foreign_key: true
      t.string :address, null: false
      t.jsonb :additional_attributes, null: false, default: {}
      t.integer :confidence_tenths
      t.datetime :as_of
      t.references :source_processing_report, null: false, foreign_key: true

      t.timestamps
    end
  end
end
