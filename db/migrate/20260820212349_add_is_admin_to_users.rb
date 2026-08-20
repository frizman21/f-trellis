# Same shape as read_only: a default means no backfill, and null: false means
# there is no third state for "is this an admin" to be in.
class AddIsAdminToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :is_admin, :boolean, default: false, null: false
  end
end
