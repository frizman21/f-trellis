# Which sources a project cares about. See #39.
#
# A join table rather than a project_id on sources: a page on the internet can
# matter to two projects at once, and the crawler that fetches it should not have
# to pick one. A column would also mean the same URL fetched twice, splitting its
# content and its processing history across two rows — what Source.for_url
# exists to prevent.
class CreateProjectSources < ActiveRecord::Migration[8.1]
  def change
    create_table :project_sources do |t|
      t.references :project, null: false, foreign_key: true
      t.references :source, null: false, foreign_key: true

      t.timestamps
    end

    # A page is on a project or it is not; twice is a duplicate, not two facts.
    add_index :project_sources, [ :project_id, :source_id ], unique: true,
              name: "index_project_sources_on_project_and_source"
  end
end
