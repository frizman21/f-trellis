# That an entity was seen in a source during one extraction run.
class EntityExtractionRun < ApplicationRecord
  include SourceCitation

  cites :entity
end
