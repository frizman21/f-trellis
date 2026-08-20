# Turns an extraction run's JSON reply into records in the project.
#
# A service rather than job code: the job's business is calling the model, and
# turning a reply into records is a separate job with its own rules — one that
# has to be testable against a JSON string with no model in the picture at all.
#
# The rules, in one place because they are the whole substance of this:
#
#   * A match is by name and type within the project, case-insensitively. A match
#     is updated rather than duplicated, which is also what makes re-running a
#     page idempotent.
#   * Anything that does not line up is skipped and reported, never coerced.
#   * A conflicting value leaves the stored one alone and cites the new source
#     against it. Nothing a person recorded is overwritten by a model.
#   * A match on a soft-deleted entity is skipped, not resurrected. Deleting it
#     was a decision.
#   * Everything recorded cites the source, at CONFIDENCE.
class ExtractionApplier
  # The model gives no confidence of its own, so everything it produces is
  # recorded as stated-by-the-source rather than as a guess about it.
  CONFIDENCE = 100

  def initialize(run)
    @run = run
    @project = run.project
    @source = run.source
    @summary = {
      "entities" => { "created" => 0, "matched" => 0, "skipped" => [] },
      "relationships" => { "created" => 0, "matched" => 0, "skipped" => [] },
      "values" => { "created" => 0, "skipped" => [], "conflicts" => [] },
      "citations" => 0
    }
    # The reply's own ids, mapped to what they resolved to. Relationship ends are
    # looked up here rather than by name or in the database: an end naming an id
    # the reply never introduced is a skip, not a search.
    @by_reply_id = {}
  end

  attr_reader :run, :project, :source, :summary

  def call
    parsed = run.parsed

    if parsed.nil?
      return summary.merge("error" => "The reply was not valid JSON, so nothing was recorded.")
    end

    # One transaction: a reply half-applied because the ninth entity failed would
    # be worse than one not applied at all, and would make re-running unsafe.
    ActiveRecord::Base.transaction do
      Array(parsed["entities"]).each { |attrs| apply_entity(attrs) }
      Array(parsed["relationships"]).each { |attrs| apply_relationship(attrs) }
    end

    summary
  end

  private

  def apply_entity(attrs)
    return skip_entity(attrs, "no name given") if attrs["name"].blank?

    type = entity_type_for(attrs["type"])
    return skip_entity(attrs, "no entity type named #{attrs['type'].inspect}") if type.nil?

    # Checked before the kept scope: a match on something deleted is a skip with
    # a reason, not a miss that quietly creates a second one alongside it.
    if find_entity(type, attrs["name"], scope: project.entities.discarded)
      return skip_entity(attrs, "matches an entity that was deleted")
    end

    entity = find_entity(type, attrs["name"], scope: project.entities.kept)

    if entity
      summary["entities"]["matched"] += 1
    else
      entity = project.entities.create!(entity_type: type, name: attrs["name"].to_s.strip)
      summary["entities"]["created"] += 1
    end

    @by_reply_id[attrs["id"].to_s] = entity if attrs["id"].present?
    cite(EntitySource, :entity, entity)
    apply_values(entity, type.entity_type_attributes.active, attrs["attributes"],
                 value_class: EntityAttributeValue, owner_key: :entity,
                 attribute_key: :entity_type_attribute,
                 citation_class: EntityAttributeValueSource, citation_key: :entity_attribute_value)
  end

  def apply_relationship(attrs)
    type = project.relationship_types.kept.find { |t| t.name.casecmp?(attrs["type"].to_s) }
    return skip_relationship(attrs, "no relationship type named #{attrs['type'].inspect}") if type.nil?

    from = @by_reply_id[attrs["from"].to_s]
    to = @by_reply_id[attrs["to"].to_s]
    return skip_relationship(attrs, "an end names an id the reply never defined") if from.nil? || to.nil?

    if from.entity_type_id != type.from_entity_type_id || to.entity_type_id != type.to_entity_type_id
      return skip_relationship(attrs, "#{type.name} joins a #{type.from_entity_type.name} to a " \
                                      "#{type.to_entity_type.name}")
    end
    return skip_relationship(attrs, "both ends are the same entity") if from.id == to.id

    relationship = project.relationships.kept
                          .find_by(relationship_type: type, from_entity: from, to_entity: to)

    if relationship
      summary["relationships"]["matched"] += 1
    else
      relationship = project.relationships.create!(relationship_type: type,
                                                   from_entity: from, to_entity: to)
      summary["relationships"]["created"] += 1
    end

    cite(RelationshipSource, :relationship, relationship)
    apply_values(relationship, type.relationship_type_attributes.active, attrs["attributes"],
                 value_class: RelationshipTypeValue, owner_key: :relationship,
                 attribute_key: :relationship_type_attribute,
                 citation_class: RelationshipTypeValueSource, citation_key: :relationship_type_value)
  end

  def apply_values(owner, declared, offered, value_class:, owner_key:, attribute_key:,
                   citation_class:, citation_key:)
    return if offered.blank? || !offered.is_a?(Hash)

    offered.each do |name, raw|
      attribute = declared.find { |a| a.name.casecmp?(name.to_s) }
      next skip_value(owner, name, "#{owner_label(owner)} has no active attribute named #{name.inspect}") if attribute.nil?
      next if raw.nil? || raw.to_s.strip.empty?

      record = value_class.find_by(owner_key => owner, attribute_key => attribute)

      if record
        # The stored value stands. Two sources disagreeing is a thing to see, not
        # something to resolve by whichever ran last.
        if record.value.to_s != cast_preview(attribute, raw).to_s
          summary["values"]["conflicts"] << {
            "owner" => owner_label(owner), "attribute" => attribute.name,
            "stored" => record.display_value, "offered" => raw.to_s
          }
        end
        cite(citation_class, citation_key, record)
        next
      end

      record = value_class.new(owner_key => owner, attribute_key => attribute)
      record.value = raw

      # #value= casts by declared type and refuses what will not cast, so this
      # skip is the model's own rule rather than a second copy of it.
      if record.valid?
        record.save!
        summary["values"]["created"] += 1
        cite(citation_class, citation_key, record)
      else
        skip_value(owner, name, record.errors.full_messages.to_sentence)
      end
    end
  end

  # What the value would become, for comparing against what is stored without
  # writing anything.
  def cast_preview(attribute, raw)
    probe = EntityAttributeValue.new(entity_type_attribute: attribute) if attribute.is_a?(EntityTypeAttribute)
    probe ||= RelationshipTypeValue.new(relationship_type_attribute: attribute)
    probe.value = raw
    probe.value
  end

  def cite(citation_class, key, record)
    citation = citation_class.find_or_initialize_by(key => record, source: source)
    return unless citation.new_record?

    citation.confidence = CONFIDENCE
    citation.save!
    summary["citations"] += 1
  end

  def entity_type_for(name)
    project.entity_types.kept.find { |t| t.name.casecmp?(name.to_s) }
  end

  def find_entity(type, name, scope:)
    scope.where(entity_type: type).find { |e| e.name.casecmp?(name.to_s.strip) }
  end

  def owner_label(owner)
    owner.is_a?(Entity) ? owner.name : "the relationship"
  end

  def skip_entity(attrs, reason)
    summary["entities"]["skipped"] << { "name" => attrs["name"].to_s, "reason" => reason }
    nil
  end

  def skip_relationship(attrs, reason)
    summary["relationships"]["skipped"] << {
      "type" => attrs["type"].to_s, "from" => attrs["from"].to_s,
      "to" => attrs["to"].to_s, "reason" => reason
    }
    nil
  end

  def skip_value(owner, name, reason)
    summary["values"]["skipped"] << {
      "owner" => owner_label(owner), "attribute" => name.to_s, "reason" => reason
    }
    nil
  end
end
