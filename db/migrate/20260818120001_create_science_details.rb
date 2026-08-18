class CreateScienceDetails < ActiveRecord::Migration[8.1]
  def change
    create_table :science_details do |t|
      t.references :science, null: false, foreign_key: true
      t.string :name, null: false
      # A field or principle is only recognisable from a one-line statement of
      # what it is about, so the summary is a column rather than a bag key —
      # the index searches it and the show page leads with it.
      t.text :summary
      t.jsonb :additional_attributes, null: false, default: {}
      t.integer :confidence_tenths
      t.datetime :as_of
      t.references :source_processing_report, null: false, foreign_key: true

      t.timestamps
    end
  end
end
