class CreateSourceImports < ActiveRecord::Migration[8.1]
  def change
    create_table :source_imports do |t|
      # What was pasted, kept so an import is auditable and re-runnable rather
      # than being a set of counts with no provenance.
      t.text :raw_urls, null: false

      t.string :status, null: false, default: "new"

      t.integer :submitted_count, null: false, default: 0
      t.integer :created_count,   null: false, default: 0
      t.integer :existing_count,  null: false, default: 0

      # [{ "value" => "...", "reason" => "..." }] — one entry per line we could
      # not turn into a Source, so a paste of two thousand says which handful
      # failed and why.
      t.jsonb :rejected, null: false, default: []

      # A failure of the job itself, as opposed to a rejected line.
      t.text :error_message

      t.timestamps
    end
  end
end
