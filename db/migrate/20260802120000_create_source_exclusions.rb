class CreateSourceExclusions < ActiveRecord::Migration[8.0]
  def change
    create_table :source_exclusions do |t|
      # An absolute URL, optionally with `*` wildcards, matched against the
      # absolute form of every link found on a page. Stored normalized (scheme
      # filled in, fragment stripped) so two spellings of the same rule cannot
      # both exist.
      t.string  :pattern, null: false
      t.text    :description
      # Switching a pattern off keeps the rule and its wording around; deleting
      # it loses why it was ever added.
      t.boolean :is_enabled, null: false, default: true

      t.timestamps
    end

    add_index :source_exclusions, :pattern, unique: true
  end
end
