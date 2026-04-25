class AddStatusAndModelToSourceProcessingReports < ActiveRecord::Migration[8.1]
  def up
    add_column :source_processing_reports, :status, :string, default: "new", null: false
    add_index  :source_processing_reports, :status
    add_reference :source_processing_reports, :model, foreign_key: true

    SourceProcessingReport.reset_column_information
    SourceProcessingReport.where(status: "new").update_all(status: "complete")
  end

  def down
    remove_reference :source_processing_reports, :model, foreign_key: true
    remove_index  :source_processing_reports, :status
    remove_column :source_processing_reports, :status
  end
end
