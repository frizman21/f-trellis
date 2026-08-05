class AddErrorToSourceProcessingReports < ActiveRecord::Migration[8.0]
  def change
    # Nullable is load-bearing here: null is how "not recorded" is stored, both
    # for reports that succeeded and for the ones that failed before this column
    # existed. Their messages went to the log and are not recoverable, and
    # backfilling a guess would be inventing history.
    add_column :source_processing_reports, :error, :text
  end
end
