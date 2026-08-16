class AddSourceDatumToSourceLinks < ActiveRecord::Migration[8.1]
  def change
    # Nullable and deliberately not backfilled. Unlike the crawl-record domain,
    # this cannot be reconstructed: an edge does not record when it was created
    # relative to the page's fetches, and attaching every old edge to the latest
    # datum would claim a snapshot that may post-date it. A null honestly means
    # "recorded before this was tracked"; a guess would look precise and be wrong.
    add_reference :source_links, :source_datum, foreign_key: true, null: true
  end
end
