# A source a project cares about.
#
# The crawling side knows nothing about projects: Source, Domain and the crawler
# are unchanged by this. A source is a page on the internet, and this is what
# makes one a given project's concern.
class ProjectSource < ApplicationRecord
  belongs_to :project
  belongs_to :source

  validates :source_id, uniqueness: { scope: :project_id }
end
