class CreateSkills < ActiveRecord::Migration[8.1]
  def change
    create_table :skills do |t|
      t.string :name
      t.string :purpose
      t.boolean :is_active, null: false, default: false

      t.timestamps
    end
  end
end
