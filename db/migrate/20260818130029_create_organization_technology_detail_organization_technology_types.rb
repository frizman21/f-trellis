# Index names given explicitly: the conventional ones run past Postgres'
# 63-character identifier limit. See docs/data-model-spec.md §4.
class CreateOrganizationTechnologyDetailOrganizationTechnologyTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :organization_technology_detail_organization_technology_types do |t|
      t.references :organization_technology_detail,
                   null: false,
                   foreign_key: true,
                   index: { name: "index_otdott_on_detail_id" }
      t.references :organization_technology_type,
                   null: false,
                   foreign_key: true,
                   index: { name: "index_otdott_on_type_id" }

      t.timestamps
    end

    add_index :organization_technology_detail_organization_technology_types,
              [ :organization_technology_detail_id, :organization_technology_type_id ],
              unique: true,
              name: "index_otdott_on_pair"
  end
end
