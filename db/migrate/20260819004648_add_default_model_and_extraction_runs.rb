# Running a project's extraction prompt against a source. See #41.
class AddDefaultModelAndExtractionRuns < ActiveRecord::Migration[8.1]
  def change
    # Nullable: a project can be created before the model registry has been
    # refreshed, and the button says so rather than the form refusing to save.
    add_reference :projects, :default_model, null: true,
                  foreign_key: { to_table: :models }

    create_table :extraction_runs do |t|
      t.references :project, null: false, foreign_key: true
      t.references :source, null: false, foreign_key: true
      # Recorded on the run rather than read back through the project, so a run
      # says which model actually answered rather than whichever one the project
      # points at when you next look.
      t.references :model, null: false, foreign_key: true
      t.references :chat, null: true, foreign_key: true

      t.string :status, null: false, default: "pending"
      # The reply as it came back. Parsing it for display is a method; the raw
      # text is what actually happened.
      t.text :response
      t.text :error
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end

    # The page asks for this source's runs, newest first.
    add_index :extraction_runs, [ :source_id, :created_at ]
    # And the button asks whether one is already in flight.
    add_index :extraction_runs, [ :project_id, :source_id, :status ],
              name: "index_extraction_runs_on_project_source_status"
  end
end
