# A type name is unique within a project, not across the system. Two projects
# each describing a "Capsule" is the normal case, not a collision — the global
# index that came in with the ontology predates projects owning it.
class ScopeEntityTypeNameUniquenessToProject < ActiveRecord::Migration[8.1]
  def change
    remove_index :entity_types, name: "index_entity_types_on_lower_name"
    add_index :entity_types, "project_id, LOWER(name)", unique: true,
              name: "index_entity_types_on_project_and_lower_name"
  end
end
