# Every entity has a name. See #28, which reverses #21.
#
# #21 gave Entity no name and derived one from an attribute called `name` when
# the type happened to declare one, falling back to "<Type> #<id>". That fallback
# is not a name, and every entity has one in practice.
class AddNameToEntities < ActiveRecord::Migration[8.1]
  def up
    # Nullable first so existing rows can be given their name before the
    # constraint lands.
    add_column :entities, :name, :string, null: true

    copy_names_from_attribute_values!
    fall_back_to_the_derived_label!

    change_column_null :entities, :name, false

    # Only now that the values have been read: after the backfill they are a
    # second copy of the column, and leaving them would let an entity's name
    # column and its name attribute disagree.
    delete_redundant_name_attributes!
  end

  def down
    remove_column :entities, :name
  end

  private

  def copy_names_from_attribute_values!
    execute <<~SQL.squish
      UPDATE entities SET name = v.string_value
      FROM entity_attribute_values v
      JOIN entity_type_attributes a ON a.id = v.entity_type_attribute_id
      WHERE v.entity_id = entities.id
        AND LOWER(a.name) = 'name'
        AND v.string_value IS NOT NULL
        AND v.string_value <> ''
    SQL
  end

  # Exactly what Entity#label rendered, so no entity's displayed name changes as
  # a result of this migration.
  def fall_back_to_the_derived_label!
    execute <<~SQL.squish
      UPDATE entities SET name = t.name || ' #' || entities.id
      FROM entity_types t
      WHERE t.id = entities.entity_type_id
        AND entities.name IS NULL
    SQL
  end

  def delete_redundant_name_attributes!
    execute <<~SQL.squish
      DELETE FROM entity_attribute_values
      WHERE entity_type_attribute_id IN (
        SELECT id FROM entity_type_attributes WHERE LOWER(name) = 'name'
      )
    SQL
    execute "DELETE FROM entity_type_attributes WHERE LOWER(name) = 'name'"
  end
end
