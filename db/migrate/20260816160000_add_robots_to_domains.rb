class AddRobotsToDomains < ActiveRecord::Migration[8.1]
  def change
    add_column :domains, :robots_txt, :text
    add_column :domains, :robots_fetched_at, :datetime

    # What happened when we asked, kept separate from the body because the body
    # alone cannot distinguish "the site has no robots.txt, so everything is
    # permitted" from "we could not reach it, so nothing is". Those two lead to
    # opposite behaviour.
    add_column :domains, :robots_status, :string

    # What the file asked for, kept separate from min_crawl_delay_seconds so a
    # site's request and an operator's override stay distinguishable.
    add_column :domains, :robots_crawl_delay_seconds, :integer
  end
end
