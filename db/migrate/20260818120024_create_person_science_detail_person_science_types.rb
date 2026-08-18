# Index names given explicitly — see
# CreatePartTechnologyDetailPartTechnologyTypes.
class CreatePersonScienceDetailPersonScienceTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :person_science_detail_person_science_types do |t|
      t.references :person_science_detail,
                   null: false,
                   foreign_key: true,
                   index: { name: "index_psdpst_on_detail_id" }
      t.references :person_science_type,
                   null: false,
                   foreign_key: true,
                   index: { name: "index_psdpst_on_type_id" }

      t.timestamps
    end

    add_index :person_science_detail_person_science_types,
              [ :person_science_detail_id, :person_science_type_id ],
              unique: true,
              name: "index_psdpst_on_pair"
  end
end
