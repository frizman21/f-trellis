# A kind of edge a project can record: what it connects, in which direction, and
# the attributes edges of that kind carry. The relationship counterpart of
# EntityType.
#
# The two ends are what make an edge checkable rather than merely labelled — a
# type that says it joins a Rocket Engine to a Launch Vehicle, while accepting an
# edge between two Contracts, would be documentation rather than a type.
class RelationshipType < ApplicationRecord
  belongs_to :project
  belongs_to :from_entity_type, class_name: "EntityType"
  belongs_to :to_entity_type,   class_name: "EntityType"

  has_many :relationship_type_attributes, -> { order(:name) }, dependent: :destroy
  has_many :relationships, dependent: :restrict_with_error

  validates :name, presence: true,
                   uniqueness: { scope: :project_id, case_sensitive: false }

  validate :ends_are_in_this_project

  def declared_attributes = relationship_type_attributes

  # The shape this type permits, for anywhere that states it in one line.
  def shape = "#{from_entity_type.name} → #{to_entity_type.name}"

  private

  # An end from another project's ontology would let a type describe entities it
  # can never legally connect.
  def ends_are_in_this_project
    return if project_id.nil?

    { from_entity_type: from_entity_type, to_entity_type: to_entity_type }.each do |name, type|
      next if type.nil? || type.project_id == project_id

      errors.add(name, "must belong to the same project as the relationship type")
    end
  end

  default_scope { order(:name) }
end
