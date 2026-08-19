# A named body of work. Operational, not a tier 1 knowledge entity: a project is
# a container the application organises work into, never a real-world subject
# extracted from a source, so it carries its name directly rather than through a
# versioned, confidence-scored detail record. See
# docs/application-data-structures.md.
class Project < ApplicationRecord
  # The two sides of a project: the ontology it describes things with, and the
  # data recorded against it. Both are destroyed with it — neither means
  # anything without the project it was defined in.
  #
  # Declared child-first, because Rails runs dependent callbacks in declaration
  # order and EntityType restricts on its entities. Types first would hit that
  # restriction and abandon the destroy, leaving the project standing.
  has_many :relationship_type_values, dependent: :destroy
  has_many :relationships, dependent: :destroy
  has_many :relationship_type_attributes, dependent: :destroy
  has_many :relationship_types, dependent: :destroy
  has_many :entity_attribute_values, dependent: :destroy
  has_many :entities, dependent: :destroy
  has_many :entity_type_attributes, dependent: :destroy
  has_many :entity_types, dependent: :destroy

  # The pages this project cares about. The joins go with the project; the
  # sources do not — they are pages on the internet, another project may be
  # using them, and a cited source cannot be deleted anyway.
  has_many :project_sources, dependent: :destroy
  has_many :sources, through: :project_sources

  validates :name, presence: true
end
