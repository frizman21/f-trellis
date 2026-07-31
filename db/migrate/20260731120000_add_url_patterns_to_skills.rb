class AddUrlPatternsToSkills < ActiveRecord::Migration[8.1]
  def change
    add_column :skills, :url_patterns, :text, array: true, null: false, default: []
  end
end
