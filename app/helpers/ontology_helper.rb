module OntologyHelper
  # Which path segment names each kind of citable fact, matching
  # PedigreesController::KINDS.
  PEDIGREE_KINDS = {
    "Entity" => "entity",
    "EntityAttributeValue" => "entity-value",
    "Relationship" => "relationship",
    "RelationshipTypeValue" => "relationship-value"
  }.freeze

  PEDIGREE_CITATIONS = {
    "Entity" => :entity_extraction_runs,
    "EntityAttributeValue" => :entity_attribute_value_extraction_runs,
    "Relationship" => :relationship_extraction_runs,
    "RelationshipTypeValue" => :relationship_type_value_extraction_runs
  }.freeze

  # Bootstrap's "clock-history": this is a record of when a fact was seen, which
  # is what a pedigree is.
  PEDIGREE_ICON = <<~SVG.html_safe.freeze
    <svg xmlns="http://www.w3.org/2000/svg" width="0.9em" height="0.9em"
         fill="currentColor" viewBox="0 0 16 16"
         aria-hidden="true" focusable="false"
         style="vertical-align: -0.1em;">
      <path d="M8.515 1.019A7 7 0 0 0 8 1V0a8 8 0 0 1 .589.022zm2.004.45a7 7 0 0 0-.985-.299l.219-.976q.576.129 1.126.342zm1.37.71a7 7 0 0 0-.439-.27l.493-.87a8 8 0 0 1 .979.654l-.615.789a7 7 0 0 0-.418-.302zm1.834 1.79a7 7 0 0 0-.653-.796l.724-.69q.406.429.747.91zm.744 1.352a7 7 0 0 0-.214-.468l.893-.45a8 8 0 0 1 .45 1.088l-.95.313a7 7 0 0 0-.179-.483m.53 2.507a7 7 0 0 0-.1-1.025l.985-.17q.1.58.116 1.17zm-.131 1.538q.05-.254.081-.51l.993.123a8 8 0 0 1-.23 1.155l-.964-.267q.069-.247.12-.501m-.952 2.379q.276-.436.486-.908l.914.405q-.24.54-.555 1.038zm-.964 1.205q.183-.183.35-.379l.758.653a8 8 0 0 1-.401.432z"/>
      <path d="M8 1a7 7 0 1 0 4.95 11.95l.707.707A8.001 8.001 0 1 1 8 0z"/>
      <path d="M7.5 3a.5.5 0 0 1 .5.5v5.21l3.248 1.856a.5.5 0 0 1-.496.868l-3.5-2A.5.5 0 0 1 7 9V3.5a.5.5 0 0 1 .5-.5"/>
    </svg>
  SVG

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

  # The pedigree icon: a link to everywhere one fact has been seen.
  #
  # An icon rather than the sources inline, because a fact seen in six runs
  # would otherwise push the value it belongs to off the row. The count is in
  # the title so the page still says how much there is to see without being
  # clicked, and a fact with nothing behind it renders a muted mark rather than
  # a link to an empty page.
  def pedigree_link(project, record)
    kind = PEDIGREE_KINDS[record.class.name]
    return if kind.nil?

    count = record.public_send(PEDIGREE_CITATIONS[record.class.name]).size

    if count.zero?
      return tag.span(PEDIGREE_ICON, class: "text-body-tertiary",
                      title: "Nothing recorded about where this came from")
    end

    link_to project_pedigree_path(project, kind: kind, id: record.id),
            class: "text-muted text-decoration-none",
            title: "Seen #{count} #{'time'.pluralize(count)} — where did this come from?",
            "aria-label": "Pedigree" do
      PEDIGREE_ICON
    end
  end

  # The fact a pedigree page is about, in one line.
  #
  # Stated on the page rather than assumed from where the reader came, because a
  # pedigree URL is bookmarkable and linkable — arriving cold, "3 sources" means
  # nothing without knowing three sources for what.
  def pedigree_subject(record)
    case record
    when Entity then "#{record.name} — #{record.entity_type.name}"
    when EntityAttributeValue
      "#{record.entity.name} · #{record.entity_type_attribute.name} = #{record.display_value}"
    when Relationship
      "#{record.from_entity.name} — #{record.relationship_type.name} → #{record.to_entity.name}"
    when RelationshipTypeValue
      "#{record.relationship.relationship_type.name} · " \
        "#{record.relationship_type_attribute.name} = #{record.display_value}"
    else record.to_s
    end
  end

  # Back to the thing the fact belongs to, so the page is not a dead end.
  def pedigree_context(project, record)
    entity = case record
             when Entity then record
             when EntityAttributeValue then record.entity
             when Relationship then record.from_entity
             when RelationshipTypeValue then record.relationship.from_entity
    end
    return "" if entity.nil?

    safe_join([ "on ", link_to(entity.name, project_entity_path(project, entity)) ])
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
