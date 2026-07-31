class CreateSourceLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :source_links do |t|
      t.references :from_source, null: false, foreign_key: { to_table: :sources, on_delete: :cascade }
      t.references :to_source,   null: false, foreign_key: { to_table: :sources, on_delete: :cascade }
      t.timestamps
    end

    add_index :source_links, [ :from_source_id, :to_source_id ], unique: true
  end
end
