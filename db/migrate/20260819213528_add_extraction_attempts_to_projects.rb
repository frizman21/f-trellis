class AddExtractionAttemptsToProjects < ActiveRecord::Migration[8.1]
  # One call and no retry, which is not what RubyLLM defaults to. An endpoint
  # that closes the connection on a long generation is retried three more times
  # by default, and the model bills for every one of them.
  def change
    add_column :projects, :extraction_attempts, :integer, default: 1, null: false
  end
end
