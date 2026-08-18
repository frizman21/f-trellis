# A kind of thing the ontology can represent, and the attributes things of that
# kind carry. Adding a new kind is a row here rather than a migration.
class EntityType < ApplicationRecord
  has_many :entity_type_attributes, -> { order(:name) }, dependent: :destroy
  has_many :entities, dependent: :restrict_with_error

  accepts_nested_attributes_for :entity_type_attributes, allow_destroy: true,
                                reject_if: :all_blank

  validates :name, presence: true,
                   uniqueness: { case_sensitive: false }

  default_scope { order(:name) }
end
