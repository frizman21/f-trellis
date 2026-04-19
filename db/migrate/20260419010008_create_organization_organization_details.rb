class CreateOrganizationOrganizationDetails < ActiveRecord::Migration[8.1]
  def change
    create_table :organization_organization_details do |t|
      t.references :organization_organization,
                   null: false,
                   foreign_key: true,
                   index: { name: "index_oo_details_on_oo_id" }
      t.references :source_processing_report,
                   null: false,
                   foreign_key: true,
                   index: { name: "index_oo_details_on_spr_id" }
      t.datetime :as_of
      t.integer :confidence_tenths
      t.jsonb :additional_attributes, null: false, default: {}

      t.timestamps
    end
  end
end
