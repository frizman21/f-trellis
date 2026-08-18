require "test_helper"

class RelationshipTypeTest < ActiveSupport::TestCase
  test "requires a name" do
    assert_not RelationshipType.new(project: projects(:apollo), name: nil).valid?
  end

  test "a name is unique within a project" do
    assert_not RelationshipType.new(project: projects(:apollo), name: "powers").valid?
  end

  # Two projects each recording a "Powers" edge is the normal case.
  test "a name used in another project is free in this one" do
    assert RelationshipType.new(project: projects(:gemini), name: "Powers").valid?
  end

  test "requires a project" do
    assert_not RelationshipType.new(name: "Orphan").valid?
  end

  # Edges of a kind mean nothing once the kind is gone.
  test "a type still in use cannot be deleted" do
    type = relationship_types(:powers)

    assert_not type.destroy
    assert RelationshipType.exists?(type.id)
  end

  test "an unused type can be deleted, and takes its attributes with it" do
    type = relationship_types(:bare_relation)
    type.relationship_type_attributes.create!(name: "note", value_type: "string")

    assert_difference -> { RelationshipTypeAttribute.count }, -1 do
      assert type.destroy
    end
  end
end
