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
    assert RelationshipType.new(project: projects(:gemini), name: "Powers",
                                from_entity_type: entity_types(:gemini_capsule),
                                to_entity_type: entity_types(:gemini_capsule)).valid?
  end

  test "requires a project" do
    assert_not RelationshipType.new(name: "Orphan").valid?
  end

  # --- the two ends ----------------------------------------------------------

  def build(**overrides)
    RelationshipType.new({ project: projects(:apollo), name: "Feeds",
                           from_entity_type: entity_types(:rocket_engine),
                           to_entity_type: entity_types(:launch_vehicle) }.merge(overrides))
  end

  test "requires both ends" do
    assert_not build(from_entity_type: nil).valid?
    assert_not build(to_entity_type: nil).valid?
  end

  test "the same entity type on both ends is allowed" do
    assert build(to_entity_type: entity_types(:rocket_engine)).valid?
  end

  test "an end from another project is rejected" do
    assert_not build(from_entity_type: entity_types(:gemini_capsule)).valid?
    assert_not build(to_entity_type: entity_types(:gemini_capsule)).valid?
  end

  test "shape states what the type connects" do
    assert_equal "Rocket Engine → Launch Vehicle", relationship_types(:powers).shape
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
