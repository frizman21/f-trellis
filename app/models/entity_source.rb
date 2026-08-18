# Where a entity was learned from, and how much to trust the citation.
class EntitySource < ApplicationRecord
  include SourceCitation

  cites :entity
end
