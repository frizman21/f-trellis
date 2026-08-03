class AddReadOnlyToUsers < ActiveRecord::Migration[8.1]
  def change
    # Defaults false so every existing account is unaffected: read-only is a
    # thing you opt an account into, never something a migration does to one.
    add_column :users, :read_only, :boolean, default: false, null: false
  end
end
