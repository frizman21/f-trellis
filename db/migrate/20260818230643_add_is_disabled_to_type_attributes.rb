# An attribute that has been used can be retired but not deleted: removing it
# would take the values recorded under it, which are knowledge, not schema.
# See #18.
class AddIsDisabledToTypeAttributes < ActiveRecord::Migration[8.1]
  def change
    # A boolean with a default has no backfill problem, so the column arrives
    # NOT NULL in one step.
    add_column :entity_type_attributes, :is_disabled, :boolean, null: false, default: false
    add_column :relationship_type_attributes, :is_disabled, :boolean, null: false, default: false
  end
end
