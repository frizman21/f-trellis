require "uri"

class CreateDomainsAndLinkSources < ActiveRecord::Migration[8.1]
  class Domain < ActiveRecord::Base; end
  class Source < ActiveRecord::Base; end

  def up
    create_table :domains do |t|
      t.string :host, null: false
      t.integer :min_crawl_delay_seconds
      t.timestamps
    end
    add_index :domains, :host, unique: true

    add_reference :sources, :domain, foreign_key: true

    Domain.reset_column_information
    Source.reset_column_information

    Source.where(domain_id: nil).find_each do |source|
      host = URI.parse(source.url.to_s).host&.downcase
      raise "Source ##{source.id} has unparseable URL: #{source.url.inspect}" if host.blank?

      domain = Domain.find_or_create_by!(host: host)
      source.update_columns(domain_id: domain.id)
    end

    change_column_null :sources, :domain_id, false
  end

  def down
    remove_reference :sources, :domain, foreign_key: true
    drop_table :domains
  end
end
