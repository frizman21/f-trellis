class CreateOrganizationDetails < ActiveRecord::Migration[8.1]
  def change
    create_table :organization_details do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.jsonb :additional_attributes, null: false, default: {}
      t.integer :confidence_tenths
      t.datetime :as_of
      t.references :source_processing_report, null: false, foreign_key: true

      t.timestamps
    end
  end
end
