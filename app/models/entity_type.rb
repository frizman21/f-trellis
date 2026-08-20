# A kind of thing the ontology can represent, and the attributes things of that
# kind carry. Adding a new kind is a row here rather than a migration.
class EntityType < ApplicationRecord
  # Soft delete, on the same terms as Entity: no default scope, because one that
  # hides rows is invisible at the call site. The reads that mean "the ontology
  # as it stands now" ask for `kept` explicitly, and each of those is tested.
  include Discard::Model
  self.discard_column = :deleted_at

  belongs_to :project

  # restrict_with_error is no longer what the delete button reaches — it
  # discards. Kept because it is still the right guard on a hard destroy from a
  # console, where cascading through entities would be silent and irreversible.
  has_many :entities, dependent: :restrict_with_error
  has_many :entity_type_attributes, -> { order(:name) }, dependent: :destroy

  # Relationship types this type is an end of, in either direction — the same
  # pair of columns EntityTypesController#show lists, needed here because
  # deleting a type has to take them with it.
  def relationship_types
    RelationshipType.where(from_entity_type_id: id).or(RelationshipType.where(to_entity_type_id: id))
  end

  # Deleting a kind of thing takes what is typed by it: its entities, their
  # edges, and the relationship types that name it.
  #
  # The relationship types are not optional. A relationship type whose `from` no
  # longer appears among the entity types is a rule no reply can satisfy, and
  # ExtractionPrompt would keep stating it — every extraction would carry an
  # unsatisfiable definition and every reply naming it would be rejected as
  # wrong_end_type. Leaving one live is worse than deleting it.
  #
  # Entities go through their own discard_with_relationships rather than being
  # discarded directly, so an entity's edges are handled by the code that
  # already owns that rule.
  def discard_with_entities
    transaction do
      entities.kept.find_each(&:discard_with_relationships)
      relationship_types.kept.find_each(&:discard_with_relationships)
      discard
    end
  end

  accepts_nested_attributes_for :entity_type_attributes, allow_destroy: true,
                                reject_if: :all_blank

  # Unique within the project, not across the system: two projects each
  # describing a "Capsule" is the normal case.
  #
  # Among the kept ones only, matching the partial index the database now
  # carries. A name a deleted type still held would be a name nothing could
  # reclaim, which is a hard delete wearing a soft one's clothes.
  validates :name, presence: true,
                   uniqueness: { scope: :project_id, case_sensitive: false,
                                 conditions: -> { kept } }

  # Slugs that already name a route under a project. A type slugging to one of
  # these would save happily and then be unreachable, because the named route
  # wins the match.
  RESERVED_SLUGS = %w[edit structure entities entity_types relationship_types relationships
                      sources project_sources ai_configuration].freeze

  # The type's address within its project: "Rocket Engine" -> "rocket-engines".
  #
  # Derived rather than stored, so renaming a type cannot leave a stale URL
  # behind pointing at it under its old name.
  def slug = name.to_s.parameterize.pluralize

  # What this type carries, for anywhere that lists it — the popover asks this
  # of an entity type and a relationship type alike.
  def declared_attributes = entity_type_attributes.active

  def index_columns = entity_type_attributes.displayed_on_index

  validate :slug_is_usable

  default_scope { order(:name) }

  private

  # Names are unique within a project, but "Rocket Engine" and "Rocket Engines"
  # are two names with one slug, and the second would be unreachable.
  def slug_is_usable
    return if name.blank?

    if RESERVED_SLUGS.include?(slug)
      errors.add(:name, "would use the address \"#{slug}\", which is reserved")
      return
    end

    # Kept only: a deleted type must not reserve an address, for the same reason
    # it must not reserve a name.
    clash = project&.entity_types&.kept&.where&.not(id: id)&.detect { |other| other.slug == slug }
    return if clash.nil?

    errors.add(:name, "would use the same address as \"#{clash.name}\"")
  end
end
