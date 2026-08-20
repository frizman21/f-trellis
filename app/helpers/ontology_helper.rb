module OntologyHelper
  # Renders a type's name with its attributes attached as a hover popover, so
  # "what does this type carry?" is answerable without leaving the page.
  #
  # Takes the type rather than a prepared list: an entity type and a
  # relationship type both answer #declared_attributes, and asking each caller
  # to assemble the same markup is how two of them end up disagreeing.
  def type_with_attributes(type, url, css_class: nil)
    link_to type.name, url,
            class: css_class,
            data: {
              controller: "type-popover",
              bs_title: type.name,
              bs_content: type_attribute_summary(type)
            }
  end

  # How many instances a type has, saying how many of them are deleted rather
  # than quietly leaving them out.
  #
  # A kept count alone is what made #66 invisible: the structure page reported
  # "0 relationships" while the delete refused because a discarded one still
  # existed, and nothing on screen could account for the contradiction. Soft
  # delete removed the refusal; this removes the contradiction's other half.
  #
  # Takes two numbers rather than a collection. Counting in Ruby would mean
  # loading every instance of every type on the page, and one project here holds
  # over a million relationships.
  #
  # Nothing is appended when nothing is deleted — the common row must not
  # acquire noise to make the rare one legible.
  def instance_count(kept, deleted)
    return kept.to_i.to_s if deleted.to_i.zero?

    safe_join([ kept.to_i.to_s, tag.span("(#{deleted} deleted)", class: "text-muted small ms-1") ])
  end

  # The popover body. Plain text rather than markup: it is set as an attribute
  # value and read back by Bootstrap, and text cannot carry an injection.
  def type_attribute_summary(type)
    attributes = type.declared_attributes
    return "No attributes defined." if attributes.empty?

    attributes.map { |attribute| "#{attribute.name} (#{attribute.value_type})" }.join("\n")
  end

  # A column header that sorts by its attribute, toggling direction and marking
  # which way the list currently runs.
  #
  # Every attribute is sortable — strings alphabetically, the rest by their own
  # ordering — so this has no "is this sortable?" branch to get wrong.
  def sort_header(attribute, current_attribute:, direction:, query:)
    active = current_attribute&.id == attribute.id
    next_direction = active && direction == "asc" ? "desc" : "asc"
    arrow = active ? (direction == "asc" ? " ↑" : " ↓") : ""

    link_to safe_join([ attribute.name, arrow ]),
            url_for(sort: attribute.name, dir: next_direction, q: query.presence),
            class: "text-decoration-none#{' fw-bold' if active}"
  end

  # The Name column's header. Name is a column on entities rather than an
  # attribute, so it sorts by its own rule and needs its own header.
  def sort_header_for_name(current_attribute:, sorted_by_name:, direction:, query:)
    active = sorted_by_name && current_attribute.nil?
    next_direction = active && direction == "asc" ? "desc" : "asc"
    arrow = active ? (direction == "asc" ? " ↑" : " ↓") : ""

    link_to safe_join([ "Name", arrow ]),
            url_for(sort: "name", dir: next_direction, q: query.presence),
            class: "text-decoration-none#{' fw-bold' if active}"
  end
end
