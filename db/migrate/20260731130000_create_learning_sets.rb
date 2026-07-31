class CreateLearningSets < ActiveRecord::Migration[8.1]
  def change
    create_table :learning_sets do |t|
      t.string :name, null: false
      t.text   :description
      t.timestamps
    end

    add_index :learning_sets, :name, unique: true

    create_table :learning_set_sources do |t|
      t.references :learning_set, null: false, foreign_key: { on_delete: :cascade }
      t.references :source, null: false, foreign_key: true
      t.timestamps
    end

    add_index :learning_set_sources, [ :learning_set_id, :source_id ],
              unique: true, name: "index_learning_set_sources_on_pair"
  end
end
