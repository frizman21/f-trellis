# Where one attribute value of an entity was learned from, and how much to trust the citation.
class EntityAttributeValueSource < ApplicationRecord
  include SourceCitation

  cites :entity_attribute_value
end
