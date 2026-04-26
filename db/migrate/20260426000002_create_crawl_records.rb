class CreateCrawlRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :crawl_records do |t|
      t.string :url, null: false
      t.timestamps
    end
    add_index :crawl_records, :url
    add_index :crawl_records, :created_at
  end
end
