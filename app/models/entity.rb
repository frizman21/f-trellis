# One thing in the ontology: an identity and a type. It carries no name column —
# anything nameable is an attribute value — so #label is the single place that
# decides what an entity is called.
class Entity < ApplicationRecord
  # The attribute whose value labels an entity, when its type declares one.
  LABEL_ATTRIBUTE = "name".freeze

  belongs_to :project
  belongs_to :entity_type

  has_many :entity_attribute_values, dependent: :destroy
  has_many :entity_sources, dependent: :destroy
  has_many :sources, through: :entity_sources
  has_many :outgoing_relationships, class_name: "Relationship",
           foreign_key: :from_entity_id, dependent: :destroy, inverse_of: :from_entity
  has_many :incoming_relationships, class_name: "Relationship",
           foreign_key: :to_entity_id, dependent: :destroy, inverse_of: :to_entity

  # A blank field for an attribute that has never been recorded is "nothing to
  # say", not a row of nulls. A blank field on a value that *does* exist is an
  # erasure and must go through, which is why the id is what distinguishes them.
  accepts_nested_attributes_for :entity_attribute_values,
                                reject_if: ->(attrs) { attrs["id"].blank? && attrs["value"].blank? }
  accepts_nested_attributes_for :entity_sources, reject_if: ->(attrs) { attrs["source_id"].blank? }

  # Data in one project cannot be typed by another project's ontology. Without
  # this, a guessed entity_type_id would quietly pull a type across the boundary
  # the whole change exists to draw.
  validate do
    next if entity_type.nil? || project_id.nil?
    next if entity_type.project_id == project_id

    errors.add(:entity_type, "must belong to the same project as the entity")
  end

  # What to call this entity. The value of its `name` attribute when it has one,
  # and "<type> #<id>" otherwise — a bare id tells a reader nothing, and the type
  # is the one thing every entity has.
  #
  # One method rather than a helper, so the index, the show page and the
  # relationship table cannot disagree about an entity's name.
  def label
    named = value_for(LABEL_ATTRIBUTE)
    named.presence || "#{entity_type.name} ##{id}"
  end

  # Every relationship this entity is an end of, in either direction. Both ends
  # are always in this entity's project, so no further scoping is needed here.
  def relationships
    Relationship.where(from_entity_id: id).or(Relationship.where(to_entity_id: id))
  end

  # This entity's values keyed by attribute id, for a table that reads many
  # attributes across many rows.
  def values_by_attribute_id = entity_attribute_values.index_by(&:entity_type_attribute_id)

  # The recorded value of a named attribute, or nil if the type has no such
  # attribute or nothing has been recorded for it.
  def value_for(attribute_name)
    pair = entity_attribute_values
           .includes(:entity_type_attribute)
           .detect { |v| v.entity_type_attribute.name.casecmp?(attribute_name) }
    pair&.value
  end

  # Every attribute of the type has a value record to bind a form field to,
  # built unsaved where nothing has been recorded yet.
  def build_missing_attribute_values
    recorded = entity_attribute_values.index_by(&:entity_type_attribute_id)

    # Active only: a retired attribute keeps what it holds but is not offered
    # for anything new.
    entity_type.entity_type_attributes.active.each do |attribute|
      next if recorded.key?(attribute.id)

      entity_attribute_values.build(entity_type_attribute: attribute)
    end
  end

  # The type's attributes paired with this entity's values, including attributes
  # with nothing recorded. The show page renders the shape of the type as well as
  # what has been filled in, so a missing value is a blank row, not a missing one.
  # Every active attribute, valued or not, plus any retired one that still holds
  # a value. "What does this type track?" and "what do we know about this thing?"
  # are different questions; dropping a recorded fact because its attribute was
  # retired would answer the second with the first.
  def attribute_rows
    recorded = entity_attribute_values.index_by(&:entity_type_attribute_id)

    entity_type.entity_type_attributes.filter_map do |attribute|
      value = recorded[attribute.id]
      next if attribute.is_disabled? && value.nil?

      [ attribute, value ]
    end
  end
end
