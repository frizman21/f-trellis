class AddSourceProcessingReportToPersonDetails < ActiveRecord::Migration[8.1]
  def change
    add_reference :person_details,
                  :source_processing_report,
                  foreign_key: true,
                  null: false
  end
end
