# An untyped edge between two entities. It carries no kind or direction
# semantics yet — that is coming.
class Relationship < ApplicationRecord
  belongs_to :from_entity, class_name: "Entity"
  belongs_to :to_entity,   class_name: "Entity"

  validate :ends_are_different

  # The far end, seen from one of them. The show page lists a relationship from
  # either side, and asking each row which entity is "the other one" is what
  # keeps it from linking back to the page it is on.
  def other_end(entity)
    from_entity_id == entity.id ? to_entity : from_entity
  end

  private

  def ends_are_different
    return if from_entity_id.blank? || to_entity_id.blank?
    return unless from_entity_id == to_entity_id

    errors.add(:to_entity, "cannot be the same entity as the from end")
  end
end
