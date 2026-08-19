# What a run did to the project: created, matched, skipped and why, and where a
# value it offered disagreed with one already recorded. See #43.
class AddSummaryToExtractionRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :extraction_runs, :summary, :jsonb, null: false, default: {}
  end
end
