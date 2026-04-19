class CreatePersonPersonDetails < ActiveRecord::Migration[8.1]
  def change
    create_table :person_person_details do |t|
      t.references :person_person, null: false, foreign_key: true
      t.references :source_processing_report, null: false, foreign_key: true
      t.datetime :as_of
      t.integer :confidence_tenths
      t.jsonb :additional_attributes, null: false, default: {}

      t.timestamps
    end
  end
end
