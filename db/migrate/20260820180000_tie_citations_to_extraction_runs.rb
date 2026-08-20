# A citation records that a fact was seen in a source *during a particular
# run* — not merely that the source mentions it. See #71.
#
# The four tables already allowed one row per (owner, source), so four sources
# stating the same birthday already produced four rows. What they could not say
# is which run saw it, which meant re-extracting a page updated history instead
# of adding to it. With the run on the row, a second extraction of the same page
# is a second sighting, and the tables are named for what they now record.
class TieCitationsToExtractionRuns < ActiveRecord::Migration[8.1]
  # New name, owner column, and the unique index's name. The last is spelled out
  # rather than derived because the derived form runs past Postgres's 63
  # character limit for two of these tables.
  TABLES = {
    "entity_sources" =>
      %w[entity_extraction_runs entity_id idx_entity_ers_on_owner_source_run],
    "relationship_sources" =>
      %w[relationship_extraction_runs relationship_id idx_relationship_ers_on_owner_source_run],
    "entity_attribute_value_sources" =>
      %w[entity_attribute_value_extraction_runs entity_attribute_value_id idx_eav_ers_on_owner_source_run],
    "relationship_type_value_sources" =>
      %w[relationship_type_value_extraction_runs relationship_type_value_id idx_rtv_ers_on_owner_source_run]
  }.freeze

  def up
    TABLES.each do |old_name, (new_name, owner_column, index_name)|
      rename_table old_name, new_name

      # The custom index names carry the old table's name and rename_table does
      # not touch them, so they are replaced rather than left lying.
      remove_index new_name, name: "index_#{old_name}_on_owner_and_source"
      # add_reference indexes the column itself, under a name Rails shortens for
      # us — which the two long table names here need.
      add_reference new_name, :extraction_run, foreign_key: true, null: true

      backfill(new_name, owner_column)

      change_column_null new_name, :extraction_run_id, false
      # One citation of a page per fact *per run*. A run seeing the same fact
      # twice is still one sighting; two runs are two.
      add_index new_name, [ owner_column, :source_id, :extraction_run_id ],
                unique: true, name: index_name
    end
  end

  def down
    TABLES.each do |old_name, (new_name, owner_column, index_name)|
      remove_index new_name, name: index_name
      remove_reference new_name, :extraction_run, foreign_key: true
      rename_table new_name, old_name
      add_index old_name, [ owner_column, :source_id ], unique: true,
                name: "index_#{old_name}_on_owner_and_source"
    end
  end

  private

  # Existing rows predate the column. Where a completed run for the same
  # (project, source) exists it is the real provenance and is used; the rest get
  # a run marked as unknown, because inventing a plausible one would assert
  # something that never happened.
  def backfill(table, owner_column)
    say_with_time "backfilling #{table}" do
      execute <<~SQL.squish
        UPDATE #{table} c
        SET extraction_run_id = (
          SELECT r.id FROM extraction_runs r
          WHERE r.source_id = c.source_id
            AND r.project_id = #{project_id_sql(table, owner_column)}
            AND r.status = 'complete'
          ORDER BY r.created_at DESC
          LIMIT 1
        )
      SQL

      orphans = select_all("SELECT id, source_id FROM #{table} WHERE extraction_run_id IS NULL").to_a
      orphans.each { |row| execute(<<~SQL.squish) }
        UPDATE #{table} SET extraction_run_id = #{unknown_run_id(table, owner_column, row['id'], row['source_id'])}
        WHERE id = #{row['id']}
      SQL
      orphans.size
    end
  end

  # How to reach the project from each citation's owner.
  def project_id_sql(table, owner_column)
    case owner_column
    when "entity_id"
      "(SELECT e.project_id FROM entities e WHERE e.id = c.#{owner_column})"
    when "relationship_id"
      "(SELECT e.project_id FROM relationships rel " \
        "JOIN entities e ON e.id = rel.from_entity_id WHERE rel.id = c.#{owner_column})"
    when "entity_attribute_value_id"
      "(SELECT e.project_id FROM entity_attribute_values v " \
        "JOIN entities e ON e.id = v.entity_id WHERE v.id = c.#{owner_column})"
    else
      "(SELECT e.project_id FROM relationship_type_values v " \
        "JOIN relationships rel ON rel.id = v.relationship_id " \
        "JOIN entities e ON e.id = rel.from_entity_id WHERE v.id = c.#{owner_column})"
    end
  end

  def unknown_run_id(table, owner_column, citation_id, source_id)
    project_id = select_value(
      "SELECT #{project_id_sql(table, owner_column).sub('c.', 'c.')} FROM #{table} c WHERE c.id = #{citation_id}"
    )
    model_id = sentinel_model_id

    existing = select_value(<<~SQL.squish)
      SELECT id FROM extraction_runs
      WHERE project_id = #{project_id} AND source_id = #{source_id}
        AND model_id = #{model_id} AND error = 'provenance predates #71'
      LIMIT 1
    SQL
    return existing if existing

    select_value(<<~SQL.squish)
      INSERT INTO extraction_runs
        (project_id, source_id, model_id, status, error, created_at, updated_at, completed_at)
      VALUES (#{project_id}, #{source_id}, #{model_id}, 'complete',
              'provenance predates #71', NOW(), NOW(), NOW())
      RETURNING id
    SQL
  end

  # The run a person's own edit belongs to needs a model, and there is no model
  # behind a person. A sentinel row rather than a nullable column: `manual` is
  # not in Model::SELECTABLE_PROVIDERS, so every picker already excludes it.
  def sentinel_model_id
    @sentinel_model_id ||= begin
      existing = select_value("SELECT id FROM models WHERE provider = 'manual' AND model_id = 'manual' LIMIT 1")
      existing || select_value(<<~SQL.squish)
        INSERT INTO models (provider, model_id, name, created_at, updated_at)
        VALUES ('manual', 'manual', 'Entered by hand', NOW(), NOW())
        RETURNING id
      SQL
    end
  end
end
