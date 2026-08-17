class RenameCrawlRecordsToFetchRecords < ActiveRecord::Migration[8.1]
  def up
    rename_table :crawl_records, :fetch_records

    # Every row that exists was written by CrawlJob, which was the only writer.
    # Defaulting to "crawl" backfills them with what actually happened rather
    # than stamping them with a trigger they never had.
    add_column :fetch_records, :trigger, :string, null: false, default: "crawl"

    # The backfill value must not become the standing default for new rows.
    # Every caller passes a trigger explicitly; this is the safety net.
    change_column_default :fetch_records, :trigger, from: "crawl", to: "manual"

    add_index :fetch_records, :trigger
  end

  def down
    remove_index :fetch_records, :trigger
    remove_column :fetch_records, :trigger
    rename_table :fetch_records, :crawl_records
  end
end
