class CreateContractDetails < ActiveRecord::Migration[8.1]
  def change
    create_table :contract_details do |t|
      t.references :contract, null: false, foreign_key: true
      # The contract number, e.g. FA2541-26-C-B007. This is what identifies a
      # contract to everyone who deals with it, so it is the key the upsert
      # matches on rather than the title, which is prose and gets reworded.
      t.string :identifier, null: false
      t.string :title
      # Typed rather than left in the property bag: an award value that cannot
      # be summed or sorted is a string that looks like a number.
      t.decimal :value_usd, precision: 15, scale: 2
      t.date :start_date
      t.date :end_date
      t.jsonb :additional_attributes, null: false, default: {}
      t.integer :confidence_tenths
      t.datetime :as_of
      t.references :source_processing_report, null: false, foreign_key: true

      t.timestamps
    end
  end
end
