class AddStatusToCrawlRecords < ActiveRecord::Migration[8.1]
  def change
    # Nullable: a connection that never produced a response has no status, and
    # inventing one (0, -1) would put a fake code in a column that will be
    # grouped and counted.
    add_column :crawl_records, :status_code, :integer

    # What makes a null status_code legible — "we asked and got nothing" is a
    # different fact from "we never asked" or "this row predates the column".
    add_column :crawl_records, :outcome, :string, null: false, default: "ok"

    add_index :crawl_records, :outcome
  end
end
