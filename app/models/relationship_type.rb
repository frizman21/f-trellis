# A kind of edge a project can record, and the attributes edges of that kind
# carry. The relationship counterpart of EntityType.
class RelationshipType < ApplicationRecord
  belongs_to :project

  has_many :relationship_type_attributes, -> { order(:name) }, dependent: :destroy
  has_many :relationships, dependent: :restrict_with_error

  validates :name, presence: true,
                   uniqueness: { scope: :project_id, case_sensitive: false }

  default_scope { order(:name) }
end
