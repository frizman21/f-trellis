class CreateScienceTechnologyTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :science_technology_types do |t|
      t.string :name, null: false
      t.text :description
      t.text :additional_attribute_keys, array: true, null: false, default: []

      t.timestamps
    end

    add_index :science_technology_types, :name, unique: true
  end
end
