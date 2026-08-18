# A project owns both of its sides: the ontology it describes things with, and
# the data recorded against it. See change request #7.
#
# Every ontology table carries the project, including the three where it is also
# reachable through a parent. The models pin those copies to their parent so they
# cannot drift; see EntityTypeAttribute, EntityAttributeValue and Relationship.
class ScopeOntologyToProject < ActiveRecord::Migration[8.1]
  TABLES = %i[
    entity_types
    entity_type_attributes
    entities
    entity_attribute_values
    relationships
  ].freeze

  def up
    # Added nullable so existing rows can be backfilled before the constraint
    # lands. A NOT NULL column with no default could not be added at all here.
    TABLES.each do |table|
      add_reference table, :project, null: true, foreign_key: true
    end

    backfill!

    TABLES.each { |table| change_column_null table, :project_id, false }
  end

  def down
    TABLES.each { |table| remove_reference table, :project, foreign_key: true }
  end

  private

  # Parent-first, so each table takes its project from the row it belongs to
  # rather than from a second guess at the same answer.
  def backfill!
    project_id = default_project_id
    return if project_id.nil?

    execute <<~SQL.squish
      UPDATE entity_types SET project_id = #{project_id} WHERE project_id IS NULL
    SQL
    execute <<~SQL.squish
      UPDATE entity_type_attributes SET project_id = entity_types.project_id
      FROM entity_types
      WHERE entity_type_attributes.entity_type_id = entity_types.id
        AND entity_type_attributes.project_id IS NULL
    SQL
    execute <<~SQL.squish
      UPDATE entities SET project_id = entity_types.project_id
      FROM entity_types
      WHERE entities.entity_type_id = entity_types.id
        AND entities.project_id IS NULL
    SQL
    execute <<~SQL.squish
      UPDATE entity_attribute_values SET project_id = entities.project_id
      FROM entities
      WHERE entity_attribute_values.entity_id = entities.id
        AND entity_attribute_values.project_id IS NULL
    SQL
    execute <<~SQL.squish
      UPDATE relationships SET project_id = entities.project_id
      FROM entities
      WHERE relationships.from_entity_id = entities.id
        AND relationships.project_id IS NULL
    SQL
  end

  # The lowest-id project, or one created to receive the rows if this database
  # predates projects entirely. Returns nil only when there is nothing to
  # backfill and no project is needed.
  def default_project_id
    existing = select_value("SELECT id FROM projects ORDER BY id LIMIT 1")
    return existing if existing.present?

    return nil if TABLES.none? { |table| select_value("SELECT 1 FROM #{table} LIMIT 1").present? }

    execute <<~SQL.squish
      INSERT INTO projects (name, created_at, updated_at)
      VALUES ('Default Project', NOW(), NOW())
    SQL
    select_value("SELECT id FROM projects ORDER BY id DESC LIMIT 1")
  end
end
