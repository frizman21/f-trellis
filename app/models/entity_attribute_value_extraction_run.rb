# That one attribute value of an entity was seen in a source during one run.
class EntityAttributeValueExtractionRun < ApplicationRecord
  include SourceCitation

  cites :entity_attribute_value
end
