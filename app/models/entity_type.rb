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

  # What this type carries, for anywhere that lists it — the popover asks this
  # of an entity type and a relationship type alike.
  def declared_attributes = entity_type_attributes

  default_scope { order(:name) }
end
