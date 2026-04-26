class AddChatToSourceProcessingReports < ActiveRecord::Migration[8.1]
  def change
    add_reference :source_processing_reports, :chat, foreign_key: true
  end
end
