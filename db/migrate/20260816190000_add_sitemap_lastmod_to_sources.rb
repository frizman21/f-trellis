class AddSitemapLastmodToSources < ActiveRecord::Migration[8.1]
  def change
    # What the site's sitemap said about when this page last changed. Written by
    # the crawl and shown on the source page; deliberately not an editable
    # control, so it does not repeat the pattern that left min_crawl_delay_
    # seconds promising behaviour nothing implemented. Using it to skip
    # unchanged pages on a re-crawl is a later card.
    add_column :sources, :sitemap_lastmod_at, :datetime
  end
end
