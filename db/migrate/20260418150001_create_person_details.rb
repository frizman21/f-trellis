class CreatePersonDetails < ActiveRecord::Migration[8.1]
  def change
    create_table :person_details do |t|
      t.references :person, null: false, foreign_key: true
      t.string :first_name
      t.string :last_name
      t.jsonb :additional_attributes, null: false, default: {}
      t.integer :confidence_tenths
      t.datetime :as_of

      t.timestamps
    end
  end
end
