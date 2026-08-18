# A kind of thing the ontology can represent, and the attributes things of that
# kind carry. Adding a new kind is a row here rather than a migration.
class EntityType < ApplicationRecord
  belongs_to :project

  has_many :entity_type_attributes, -> { order(:name) }, dependent: :destroy
  has_many :entities, dependent: :restrict_with_error

  accepts_nested_attributes_for :entity_type_attributes, allow_destroy: true,
                                reject_if: :all_blank

  # Unique within the project, not across the system: two projects each
  # describing a "Capsule" is the normal case.
  validates :name, presence: true,
                   uniqueness: { scope: :project_id, case_sensitive: false }

  # Slugs that already name a route under a project. A type slugging to one of
  # these would save happily and then be unreachable, because the named route
  # wins the match.
  RESERVED_SLUGS = %w[edit structure entities entity_types relationship_types relationships].freeze

  # The type's address within its project: "Rocket Engine" -> "rocket-engines".
  #
  # Derived rather than stored, so renaming a type cannot leave a stale URL
  # behind pointing at it under its old name.
  def slug = name.to_s.parameterize.pluralize

  # What this type carries, for anywhere that lists it — the popover asks this
  # of an entity type and a relationship type alike.
  def declared_attributes = entity_type_attributes

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

    clash = project&.entity_types&.where&.not(id: id)&.detect { |other| other.slug == slug }
    return if clash.nil?

    errors.add(:name, "would use the same address as \"#{clash.name}\"")
  end
end
