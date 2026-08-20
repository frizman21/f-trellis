# That a relationship was seen in a source during one extraction run.
class RelationshipExtractionRun < ApplicationRecord
  include SourceCitation

  cites :relationship
end
