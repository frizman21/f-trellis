class AddValidatorsToSources < ActiveRecord::Migration[8.1]
  def change
    # What the last response said about this page's identity, so the next
    # request can ask "only if it changed". They live on Source rather than
    # SourceDatum because a 304 produces no datum at all — hanging them off a
    # record that does not get created would not work.
    add_column :sources, :etag, :string
    add_column :sources, :last_modified_at, :datetime
  end
end
