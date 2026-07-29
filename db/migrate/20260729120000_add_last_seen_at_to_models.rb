class AddLastSeenAtToModels < ActiveRecord::Migration[8.1]
  def up
    add_column :models, :last_seen_at, :datetime
    add_index  :models, :last_seen_at

    # Backfill every existing row with a single shared timestamp so that
    # `Model.current` (which selects rows stamped by the most recent refresh)
    # returns the whole registry until the first real refresh runs.
    Model.reset_column_information
    Model.update_all(last_seen_at: Time.current)
  end

  def down
    remove_index  :models, :last_seen_at
    remove_column :models, :last_seen_at
  end
end
