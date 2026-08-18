# An untyped edge between two entities. It carries no kind or direction
# semantics yet — that is coming.
class Relationship < ApplicationRecord
  include ScopedToProject

  belongs_to :from_entity, class_name: "Entity"
  belongs_to :to_entity,   class_name: "Entity"
  scoped_to_project_through :from_entity

  validate :ends_are_different
  validate :ends_share_a_project

  # The far end, seen from one of them. The show page lists a relationship from
  # either side, and asking each row which entity is "the other one" is what
  # keeps it from linking back to the page it is on.
  def other_end(entity)
    from_entity_id == entity.id ? to_entity : from_entity
  end

  private

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
