class AddResolvedUrlToSources < ActiveRecord::Migration[8.1]
  def change
    # Where the content actually came from, when a redirect moved it. Left null
    # when the fetched URL is the source's own. `url` is deliberately not
    # rewritten: it is the identity a crawl dedupes on.
    add_column :sources, :resolved_url, :string
  end
end
