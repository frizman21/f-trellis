# That one attribute value of a relationship was seen in a source during one run.
class RelationshipTypeValueExtractionRun < ApplicationRecord
  include SourceCitation

  cites :relationship_type_value
end
