# Where one attribute value of a relationship was learned from, and how much to trust the citation.
class RelationshipTypeValueSource < ApplicationRecord
  include SourceCitation

  cites :relationship_type_value
end
