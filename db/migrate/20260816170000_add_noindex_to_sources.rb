class AddNoindexToSources < ActiveRecord::Migration[8.1]
  def change
    # The page asked not to be kept as a retrievable record. It can still be
    # fetched and read; it just does not become knowledge-graph input.
    add_column :sources, :is_noindex, :boolean, null: false, default: false
    add_index :sources, :is_noindex
  end
end
