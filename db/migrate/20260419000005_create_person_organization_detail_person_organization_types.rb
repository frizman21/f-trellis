class CreatePersonOrganizationDetailPersonOrganizationTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :person_organization_detail_person_organization_types do |t|
      t.references :person_organization_detail, null: false, foreign_key: true, index: { name: "index_podpot_on_detail_id" }
      t.references :person_organization_type,   null: false, foreign_key: true, index: { name: "index_podpot_on_type_id" }

      t.timestamps
    end

    add_index :person_organization_detail_person_organization_types,
              [ :person_organization_detail_id, :person_organization_type_id ],
              unique: true,
              name: "index_podpot_on_detail_and_type"
  end
end
