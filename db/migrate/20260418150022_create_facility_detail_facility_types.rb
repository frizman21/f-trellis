class CreateFacilityDetailFacilityTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :facility_detail_facility_types do |t|
      t.references :facility_detail, null: false, foreign_key: true
      t.references :facility_type,   null: false, foreign_key: true

      t.timestamps
    end

    add_index :facility_detail_facility_types,
              [ :facility_detail_id, :facility_type_id ],
              unique: true,
              name: "index_fdft_on_detail_and_type"
  end
end
