class AddContentHashToSourceData < ActiveRecord::Migration[8.1]
  def up
    add_column :source_data, :content_hash, :string
    add_index :source_data, :content_hash

    # Backfill by unzipping and extracting each payload. Done in Ruby rather
    # than SQL because the hash is over the *extracted text*, not the stored
    # bytes, so two fetches that differ only in markup collapse to one hash.
    SourceDatum.reset_column_information
    SourceDatum.find_each do |datum|
      datum.update_column(:content_hash, datum.send(:computed_content_hash))
    rescue StandardError => e
      say "skipping datum ##{datum.id}: #{e.class}: #{e.message}"
    end
  end

  def down
    remove_index :source_data, :content_hash
    remove_column :source_data, :content_hash
  end
end
