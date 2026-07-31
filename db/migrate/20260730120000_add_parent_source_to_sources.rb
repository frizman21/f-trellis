class AddParentSourceToSources < ActiveRecord::Migration[8.1]
  def change
    add_reference :sources, :parent_source,
                  null: true,
                  foreign_key: { to_table: :sources, on_delete: :nullify }
  end
end
