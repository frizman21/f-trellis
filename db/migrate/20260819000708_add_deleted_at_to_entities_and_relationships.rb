# Soft delete for entities and relationships. See #35.
#
# What is recorded is knowledge, and a mis-click should not be the end of it —
# the same argument #18 made about retiring an attribute rather than deleting it.
class AddDeletedAtToEntitiesAndRelationships < ActiveRecord::Migration[8.1]
  def change
    add_column :entities, :deleted_at, :datetime
    add_column :relationships, :deleted_at, :datetime

    # Partial indexes: every read that matters asks for the kept rows, and the
    # deleted ones are the minority the index does not need to carry.
    add_index :entities, :deleted_at, where: "deleted_at IS NULL",
              name: "index_entities_on_kept"
    add_index :relationships, :deleted_at, where: "deleted_at IS NULL",
              name: "index_relationships_on_kept"
  end
end
