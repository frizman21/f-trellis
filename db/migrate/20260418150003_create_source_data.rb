class CreateSourceData < ActiveRecord::Migration[8.1]
  def change
    create_table :source_data do |t|
      t.references :source, null: false, foreign_key: true
      t.string :content_type
      t.binary :data

      t.timestamps
    end
  end
end
