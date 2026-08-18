# Where a relationship was learned from, and how much to trust the citation.
class RelationshipSource < ApplicationRecord
  include SourceCitation

  cites :relationship
end
