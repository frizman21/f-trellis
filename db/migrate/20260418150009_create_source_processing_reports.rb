class CreateSourceProcessingReports < ActiveRecord::Migration[8.1]
  def change
    create_table :source_processing_reports do |t|
      t.references :source,          null: false, foreign_key: true
      t.references :skill_revision,  null: false, foreign_key: true
      t.jsonb :facts, null: false, default: {}

      t.timestamps
    end
  end
end
