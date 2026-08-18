# Citing the source a recorded fact came from, with a confidence in the
# citation. See #9.
#
# Four tables rather than one polymorphic one: a real foreign key per citable
# thing means the database enforces that a citation points at something that
# exists, which a polymorphic owner_type/owner_id pair cannot.
class CreateSourceCitations < ActiveRecord::Migration[8.1]
  CITABLE = {
    entity_sources: :entity,
    relationship_sources: :relationship,
    entity_attribute_value_sources: :entity_attribute_value,
    relationship_type_value_sources: :relationship_type_value
  }.freeze

  def change
    CITABLE.each do |table, owner|
      create_table table do |t|
        t.references owner, null: false, foreign_key: true
        t.references :source, null: false, foreign_key: true
        # 1..100. Defaulted rather than nullable: a citation with no confidence
        # in it is a citation that cannot be weighed, and "as stated" is 100.
        t.integer :confidence, null: false, default: 100

        t.timestamps
      end

      # The same source cited twice for the same fact is a duplicate, not two
      # citations.
      add_index table, [ :"#{owner}_id", :source_id ], unique: true,
                name: "index_#{table}_on_owner_and_source"
    end
  end
end
