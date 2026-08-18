class CreateScienceTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :science_types do |t|
      t.string :name, null: false
      t.text :description
      t.text :additional_attribute_keys, array: true, null: false, default: []

      t.timestamps
    end

    add_index :science_types, :name, unique: true
  end
end
