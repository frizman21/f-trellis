class CreatePersonPersonDetailPersonPersonTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :person_person_detail_person_person_types do |t|
      t.references :person_person_detail, null: false, foreign_key: true, index: { name: "index_ppdppt_on_detail_id" }
      t.references :person_person_type,   null: false, foreign_key: true, index: { name: "index_ppdppt_on_type_id" }

      t.timestamps
    end

    add_index :person_person_detail_person_person_types,
              [ :person_person_detail_id, :person_person_type_id ],
              unique: true,
              name: "index_ppdppt_on_detail_and_type"
  end
end
