# A named body of work. Operational, not a tier 1 knowledge entity: a project is
# a container the application organises work into, never a real-world subject
# extracted from a source, so it carries its name directly rather than through a
# versioned, confidence-scored detail record. See
# docs/application-data-structures.md.
class Project < ApplicationRecord
  validates :name, presence: true
end
