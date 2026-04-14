class CreateSources < ActiveRecord::Migration[8.1]
  def change
    create_table :sources do |t|
      t.string :url
      t.text :description

      t.timestamps
    end
  end
end
