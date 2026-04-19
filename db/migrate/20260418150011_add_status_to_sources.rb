class AddStatusToSources < ActiveRecord::Migration[8.1]
  def change
    add_column :sources, :status, :string, null: false, default: "new"
    add_index :sources, :status
  end
end
