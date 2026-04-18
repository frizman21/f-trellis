class CreatePersonDetailPersonTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :person_detail_person_types do |t|
      t.references :person_detail, null: false, foreign_key: true
      t.references :person_type,   null: false, foreign_key: true

      t.timestamps
    end

    add_index :person_detail_person_types,
              [ :person_detail_id, :person_type_id ],
              unique: true,
              name: "index_pdpt_on_detail_and_type"
  end
end
