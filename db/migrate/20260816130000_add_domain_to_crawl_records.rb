class AddDomainToCrawlRecords < ActiveRecord::Migration[8.1]
  def up
    add_reference :crawl_records, :domain, foreign_key: true, null: true

    # Backfillable, unlike the content type: the URL was recorded, so the host
    # is still derivable. A CrawlRecord is only ever written for a URL a Source
    # already held, so no row is expected to fail this.
    CrawlRecord.reset_column_information
    CrawlRecord.where(domain_id: nil).find_each do |record|
      domain = Domain.for_url(record.url)
      record.update_columns(domain_id: domain.id) if domain
    end

    orphans = CrawlRecord.where(domain_id: nil).count
    raise ActiveRecord::IrreversibleMigration, "#{orphans} crawl_records have unparseable URLs" if orphans.positive?

    change_column_null :crawl_records, :domain_id, false
  end

  def down
    remove_reference :crawl_records, :domain, foreign_key: true
  end
end
