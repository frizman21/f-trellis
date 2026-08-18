# Relationships gain the typing the entity side already has: a kind, typed
# attributes on that kind, and values recorded against an edge. See #8.
class CreateRelationshipTypes < ActiveRecord::Migration[8.1]
  def up
    create_table :relationship_types do |t|
      t.references :project, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description

      t.timestamps
    end
    # Unique within the project, not across the system — as with entity types.
    add_index :relationship_types, "project_id, LOWER(name)", unique: true,
              name: "index_relationship_types_on_project_and_lower_name"

    create_table :relationship_type_attributes do |t|
      t.references :project, null: false, foreign_key: true
      t.references :relationship_type, null: false, foreign_key: true
      t.string :name, null: false
      # Not `type`: reserved by Rails for single-table inheritance.
      t.string :value_type, null: false

      t.timestamps
    end
    add_index :relationship_type_attributes, [ :relationship_type_id, :name ], unique: true,
              name: "index_relationship_type_attributes_on_type_and_name"

    create_table :relationship_type_values do |t|
      t.references :project, null: false, foreign_key: true
      t.references :relationship, null: false, foreign_key: true
      t.references :relationship_type_attribute, null: false, foreign_key: true

      # Exactly one of these is live, chosen by the attribute's value_type.
      t.integer  :int_value
      t.float    :float_value
      t.string   :string_value
      t.datetime :datetime_value

      t.timestamps
    end
    add_index :relationship_type_values, [ :relationship_id, :relationship_type_attribute_id ],
              unique: true, name: "index_relationship_type_values_on_relationship_and_attribute"

    # Added nullable so existing edges can be given a kind before the constraint
    # lands. They predate the concept, and "Related" is the honest answer.
    add_reference :relationships, :relationship_type, null: true, foreign_key: true
    backfill_relationship_types!
    change_column_null :relationships, :relationship_type_id, false
  end

  def down
    remove_reference :relationships, :relationship_type, foreign_key: true
    drop_table :relationship_type_values
    drop_table :relationship_type_attributes
    drop_table :relationship_types
  end

  private

  # One "Related" type per project that actually has edges. A project with no
  # relationships gets no type it never asked for.
  def backfill_relationship_types!
    project_ids = select_values("SELECT DISTINCT project_id FROM relationships")

    project_ids.each do |project_id|
      execute <<~SQL.squish
        INSERT INTO relationship_types (project_id, name, description, created_at, updated_at)
        VALUES (#{project_id.to_i}, 'Related',
                'Edges that predate relationship types.', NOW(), NOW())
      SQL
      type_id = select_value("SELECT id FROM relationship_types ORDER BY id DESC LIMIT 1")
      execute <<~SQL.squish
        UPDATE relationships SET relationship_type_id = #{type_id.to_i}
        WHERE project_id = #{project_id.to_i} AND relationship_type_id IS NULL
      SQL
    end
  end
end
