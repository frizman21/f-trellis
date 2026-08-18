# The ontology that replaces the removed tier 1 entity model (#4): types, typed
# attributes, instances, values, and untyped edges between instances.
#
# Adding a new kind of thing is now a row in entity_types rather than a
# migration, which was the specific failure of the model this replaces.
class CreateOntology < ActiveRecord::Migration[8.1]
  def change
    create_table :entity_types do |t|
      t.string :name, null: false
      t.text :description

      t.timestamps
    end
    add_index :entity_types, "LOWER(name)", unique: true, name: "index_entity_types_on_lower_name"

    create_table :entity_type_attributes do |t|
      t.references :entity_type, null: false, foreign_key: true
      t.string :name, null: false
      # Not `type`: Rails reserves that column for single-table inheritance and
      # would try to instantiate a class named "int" on every load.
      t.string :value_type, null: false

      t.timestamps
    end
    add_index :entity_type_attributes, [ :entity_type_id, :name ], unique: true,
              name: "index_entity_type_attributes_on_type_and_name"

    create_table :entities do |t|
      # No name column. An entity is identity plus its type; anything nameable
      # is an attribute value.
      t.references :entity_type, null: false, foreign_key: true

      t.timestamps
    end

    create_table :entity_attribute_values do |t|
      t.references :entity, null: false, foreign_key: true
      t.references :entity_type_attribute, null: false, foreign_key: true

      # Exactly one of these is live, chosen by the attribute's value_type.
      t.integer  :int_value
      t.float    :float_value
      t.string   :string_value
      t.datetime :datetime_value

      t.timestamps
    end
    # One value per attribute per entity — two rows for the same pair would make
    # "the value" ambiguous with nothing to break the tie.
    add_index :entity_attribute_values, [ :entity_id, :entity_type_attribute_id ],
              unique: true, name: "index_entity_attribute_values_on_entity_and_attribute"

    create_table :relationships do |t|
      t.references :from_entity, null: false, foreign_key: { to_table: :entities }
      t.references :to_entity,   null: false, foreign_key: { to_table: :entities }

      t.timestamps
    end
  end
end
