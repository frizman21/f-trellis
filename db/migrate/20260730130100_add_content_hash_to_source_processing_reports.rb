class AddContentHashToSourceProcessingReports < ActiveRecord::Migration[8.1]
  def up
    add_column :source_processing_reports, :content_hash, :string

    # Stamp existing reports from the payload they were run against so the
    # uniqueness index below does not reject the history already recorded.
    SourceProcessingReport.reset_column_information
    SourceProcessingReport.includes(source: :source_data).find_each do |report|
      hash = report.source&.source_data&.order(:created_at)&.last&.content_hash
      report.update_column(:content_hash, hash) if hash
    end

    deduplicate_existing

    add_index :source_processing_reports,
              [ :source_id, :skill_revision_id, :content_hash ],
              unique: true,
              name: "index_reports_on_source_skill_revision_and_content"
  end

  def down
    remove_index :source_processing_reports, name: "index_reports_on_source_skill_revision_and_content"
    remove_column :source_processing_reports, :content_hash
  end

  private

  # Rows predating this change may already duplicate the triple. Keep the
  # earliest of each group and null the rest's hash rather than deleting
  # reports, which own detail records.
  def deduplicate_existing
    SourceProcessingReport
      .where.not(content_hash: nil)
      .group(:source_id, :skill_revision_id, :content_hash)
      .having("COUNT(*) > 1")
      .count
      .each_key do |source_id, skill_revision_id, content_hash|
        duplicates = SourceProcessingReport
                       .where(source_id:, skill_revision_id:, content_hash:)
                       .order(:id)
                       .offset(1)

        say "nulling content_hash on #{duplicates.count} duplicate report(s) " \
            "for source #{source_id} / revision #{skill_revision_id}"
        duplicates.update_all(content_hash: nil)
      end
  end
end
