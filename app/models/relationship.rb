# An edge between two entities, of a kind the project defines, carrying whatever
# attributes that kind declares.
class Relationship < ApplicationRecord
  include ScopedToProject

  belongs_to :relationship_type
  belongs_to :from_entity, class_name: "Entity"
  belongs_to :to_entity,   class_name: "Entity"
  scoped_to_project_through :from_entity

  has_many :relationship_type_values, dependent: :destroy
  has_many :relationship_sources, dependent: :destroy
  has_many :sources, through: :relationship_sources

  accepts_nested_attributes_for :relationship_type_values,
                                reject_if: ->(attrs) { attrs["id"].blank? && attrs["value"].blank? }
  accepts_nested_attributes_for :relationship_sources, reject_if: ->(attrs) { attrs["source_id"].blank? }

  validate :ends_are_different
  validate :ends_share_a_project
  validate :type_is_in_the_same_project
  validate :ends_match_the_type

  # The far end, seen from one of them. The show page lists a relationship from
  # either side, and asking each row which entity is "the other one" is what
  # keeps it from linking back to the page it is on.
  def other_end(entity)
    from_entity_id == entity.id ? to_entity : from_entity
  end

  def values_by_attribute_id = relationship_type_values.index_by(&:relationship_type_attribute_id)

  # The type's attributes paired with this relationship's values, including
  # attributes with nothing recorded — the same shape the entity side shows, so
  # a blank is a row rather than a missing one.
  def attribute_rows
    recorded = relationship_type_values.index_by(&:relationship_type_attribute_id)

    relationship_type.relationship_type_attributes.filter_map do |attribute|
      value = recorded[attribute.id]
      next if attribute.is_disabled? && value.nil?

      [ attribute, value ]
    end
  end

  # Every attribute of the type has a value record to bind a form field to,
  # built unsaved where nothing has been recorded yet.
  def build_missing_attribute_values
    recorded = relationship_type_values.index_by(&:relationship_type_attribute_id)

    relationship_type.relationship_type_attributes.active.each do |attribute|
      next if recorded.key?(attribute.id)

      relationship_type_values.build(relationship_type_attribute: attribute)
    end
  end

  private

  # The type says what it connects, and that is checked rather than assumed.
  # Direction is not symmetric: a type from A to B does not permit B to A, so
  # each end is checked against its own declared type rather than against the
  # pair as a set.
  def ends_match_the_type
    return if relationship_type.nil?

    if from_entity && from_entity.entity_type_id != relationship_type.from_entity_type_id
      errors.add(:from_entity,
                 "must be a #{relationship_type.from_entity_type.name} " \
                 "for a #{relationship_type.name} relationship")
    end

    return unless to_entity && to_entity.entity_type_id != relationship_type.to_entity_type_id

    errors.add(:to_entity,
               "must be a #{relationship_type.to_entity_type.name} " \
               "for a #{relationship_type.name} relationship")
  end

  # As with an entity and its type: one project's edges cannot be typed by
  # another project's ontology.
  def type_is_in_the_same_project
    return if relationship_type.nil? || project_id.nil?
    return if relationship_type.project_id == project_id

    errors.add(:relationship_type, "must belong to the same project as the relationship")
  end

  # An edge across projects would make one project's data reachable from
  # another's, which is the one thing scoping is for.
  def ends_share_a_project
    return if from_entity.nil? || to_entity.nil?
    return if from_entity.project_id == to_entity.project_id

    errors.add(:to_entity, "must belong to the same project as the from end")
  end

  def ends_are_different
    return if from_entity_id.blank? || to_entity_id.blank?
    return unless from_entity_id == to_entity_id

    errors.add(:to_entity, "cannot be the same entity as the from end")
  end
end
