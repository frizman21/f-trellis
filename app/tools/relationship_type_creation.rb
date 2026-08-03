# Plumbing shared by the tools that mint relationship types.
#
# These tools are the odd ones out among the writing tools: they add vocabulary,
# not knowledge. Nothing here is attached to a SourceProcessingReport, because a
# type is not a claim about the world that one source can make and another
# contradict — it is a name the whole knowledge base agrees to use.
module RelationshipTypeCreation
  private

  # Matching is case-insensitive even though the unique index is not. The danger
  # in letting a model name things is not a bad type; it is "Employment",
  # "employment" and "EMPLOYMENT" sitting in the list as three separate ideas.
  def upsert_relationship_type(type_class, attrs)
    existing = existing_relationship_type(type_class, attrs[:name])
    return [ existing, false ] if existing

    [ type_class.create!(**attrs), true ]
  end

  def existing_relationship_type(type_class, name)
    type_class.where("LOWER(name) = ?", name.downcase).first
  end

  # Returns [attrs, error]. A type with no description is vocabulary nobody can
  # review later, which defeats the point of recording who meant what.
  def relationship_type_attributes(name:, description:, additional_attribute_keys:)
    attrs = {
      name: name.to_s.strip,
      description: description.to_s.strip,
      additional_attribute_keys: normalize_attribute_keys(additional_attribute_keys)
    }

    return [ attrs, { error: "name is required" } ] if attrs[:name].empty?
    return [ attrs, { error: "description is required" } ] if attrs[:description].empty?

    [ attrs, nil ]
  end

  def normalize_attribute_keys(keys)
    Array(keys).filter_map { |key| key.to_s.strip.presence }.uniq
  end
end
