# A relationship type says what it connects: the kind of thing an edge of that
# kind starts at, and the kind it ends at. See #11.
class AddEndsToRelationshipTypes < ActiveRecord::Migration[8.1]
  def up
    # Nullable first so existing types can be given a shape before the
    # constraint lands.
    add_reference :relationship_types, :from_entity_type, null: true,
                  foreign_key: { to_table: :entity_types }
    add_reference :relationship_types, :to_entity_type, null: true,
                  foreign_key: { to_table: :entity_types }

    backfill_ends!

    change_column_null :relationship_types, :from_entity_type_id, false
    change_column_null :relationship_types, :to_entity_type_id, false
  end

  def down
    remove_reference :relationship_types, :from_entity_type, foreign_key: { to_table: :entity_types }
    remove_reference :relationship_types, :to_entity_type, foreign_key: { to_table: :entity_types }
  end

  private

  def backfill_ends!
    ensure_every_project_can_be_typed!
    infer_ends_from_existing_edges!
    report_edges_that_disagree!
    fall_back_to_the_projects_first_entity_type!
  end

  # A project with relationship types but no entity types cannot fill in either
  # end — and cannot have edges either, since no entity types means no entities.
  # Rather than delete what someone typed or leave the column null, give that
  # project a type to point at. It is visible and renameable like any other.
  def ensure_every_project_can_be_typed!
    execute <<~SQL.squish
      INSERT INTO entity_types (project_id, name, description, created_at, updated_at)
      SELECT DISTINCT rt.project_id, 'Unspecified',
             'Created so relationship types in this project could declare their ends.',
             NOW(), NOW()
      FROM relationship_types rt
      WHERE NOT EXISTS (
        SELECT 1 FROM entity_types et WHERE et.project_id = rt.project_id
      )
    SQL
  end

  # A type that already has edges takes its shape from them, so every stored
  # edge conforms to its type by construction and the new validation invalidates
  # nothing that already exists. The lowest-id edge decides.
  def infer_ends_from_existing_edges!
    execute <<~SQL.squish
      UPDATE relationship_types rt
      SET from_entity_type_id = shape.from_type_id,
          to_entity_type_id   = shape.to_type_id
      FROM (
        SELECT DISTINCT ON (r.relationship_type_id)
               r.relationship_type_id,
               from_e.entity_type_id AS from_type_id,
               to_e.entity_type_id   AS to_type_id
        FROM relationships r
        JOIN entities from_e ON from_e.id = r.from_entity_id
        JOIN entities to_e   ON to_e.id   = r.to_entity_id
        ORDER BY r.relationship_type_id, r.id
      ) AS shape
      WHERE rt.id = shape.relationship_type_id
    SQL
  end

  # Where a type's edges disagree about their shape, the lowest-id one won above
  # and the rest are now invalid on next save. Said out loud rather than resolved
  # silently: which shape is right is a judgement about the data, not a migration.
  def report_edges_that_disagree!
    rows = select_all(<<~SQL.squish)
      SELECT rt.name AS type_name, COUNT(*) AS offending
      FROM relationships r
      JOIN relationship_types rt ON rt.id = r.relationship_type_id
      JOIN entities from_e ON from_e.id = r.from_entity_id
      JOIN entities to_e   ON to_e.id   = r.to_entity_id
      WHERE rt.from_entity_type_id IS NOT NULL
        AND (from_e.entity_type_id <> rt.from_entity_type_id
             OR to_e.entity_type_id <> rt.to_entity_type_id)
      GROUP BY rt.name
    SQL

    rows.each do |row|
      say "Relationship type #{row['type_name'].inspect}: #{row['offending']} existing " \
          "edge(s) do not match the shape inferred from its lowest-id edge. They remain " \
          "stored and will fail validation on next save."
    end
  end

  # A type with no edges constrains nothing that exists, so any of its project's
  # entity types will do as a starting point. Editable on the type's own form.
  def fall_back_to_the_projects_first_entity_type!
    execute <<~SQL.squish
      UPDATE relationship_types rt
      SET from_entity_type_id = COALESCE(rt.from_entity_type_id, fallback.id),
          to_entity_type_id   = COALESCE(rt.to_entity_type_id, fallback.id)
      FROM (
        SELECT DISTINCT ON (project_id) project_id, id
        FROM entity_types ORDER BY project_id, id
      ) AS fallback
      WHERE fallback.project_id = rt.project_id
        AND (rt.from_entity_type_id IS NULL OR rt.to_entity_type_id IS NULL)
    SQL
  end
end
