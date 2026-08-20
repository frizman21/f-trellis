# Soft delete for the two type models. See #66.
#
# The instances have been recoverable since #35; the definitions were not, and
# they are the more consequential thing to lose. The guard that stood in for it
# — dependent: :restrict_with_error — counted discarded rows too, so a
# relationship removed through the UI blocked its type from ever being deleted
# while every screen reported none.
class AddDeletedAtToEntityTypesAndRelationshipTypes < ActiveRecord::Migration[8.1]
  def change
    add_column :entity_types, :deleted_at, :datetime
    add_column :relationship_types, :deleted_at, :datetime

    # Partial, for the same reason #35's are: every read that matters asks for
    # the kept rows.
    add_index :entity_types, :deleted_at, where: "deleted_at IS NULL",
              name: "index_entity_types_on_kept"
    add_index :relationship_types, :deleted_at, where: "deleted_at IS NULL",
              name: "index_relationship_types_on_kept"

    # The name indexes are unique in the database, not only in the model. Left
    # as they are, reusing a deleted type's name raises PG::UniqueViolation
    # rather than failing validation — and a name a deleted type still holds is
    # a name nothing can reclaim. Recreated over the kept rows only.
    remove_index :entity_types, name: "index_entity_types_on_project_and_lower_name"
    add_index :entity_types, "project_id, lower(name)", unique: true,
              where: "deleted_at IS NULL",
              name: "index_entity_types_on_project_and_lower_name"

    remove_index :relationship_types, name: "index_relationship_types_on_project_and_lower_name"
    add_index :relationship_types, "project_id, lower(name)", unique: true,
              where: "deleted_at IS NULL",
              name: "index_relationship_types_on_project_and_lower_name"
  end
end
