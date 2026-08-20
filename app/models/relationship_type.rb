# A kind of edge a project can record: what it connects, in which direction, and
# the attributes edges of that kind carry. The relationship counterpart of
# EntityType.
#
# The two ends are what make an edge checkable rather than merely labelled — a
# type that says it joins a Rocket Engine to a Launch Vehicle, while accepting an
# edge between two Contracts, would be documentation rather than a type.
class RelationshipType < ApplicationRecord
  # Soft delete, on the same terms as Relationship and EntityType: no default
  # scope, and the reads that mean "the ontology as it stands now" say `kept`.
  include Discard::Model
  self.discard_column = :deleted_at

  belongs_to :project
  belongs_to :from_entity_type, class_name: "EntityType"
  belongs_to :to_entity_type,   class_name: "EntityType"

  # Kept for a hard destroy from a console. It is no longer what the delete
  # button reaches, and it was never the guard it appeared to be: it counts
  # discarded rows too, so a relationship removed through the UI blocked its own
  # type from ever being deleted (#66).
  has_many :relationships, dependent: :restrict_with_error
  has_many :relationship_type_attributes, -> { order(:name) }, dependent: :destroy

  accepts_nested_attributes_for :relationship_type_attributes, allow_destroy: true,
                                reject_if: :all_blank

  # Among the kept ones only, matching the partial index the database carries.
  validates :name, presence: true,
                   uniqueness: { scope: :project_id, case_sensitive: false,
                                 conditions: -> { kept } }

  validate :ends_are_in_this_project

  # Deleting a kind of edge takes the edges of that kind: an edge whose kind the
  # project no longer defines is not a fact, which is the argument
  # Entity#discard_with_relationships already makes about dangling edges.
  #
  # Already-discarded relationships are left alone rather than re-discarded, so
  # a cascade cannot restamp when something was deleted.
  def discard_with_relationships
    transaction do
      relationships.kept.find_each(&:discard)
      discard
    end
  end

  def declared_attributes = relationship_type_attributes.active

  def index_columns = relationship_type_attributes.displayed_on_index

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
