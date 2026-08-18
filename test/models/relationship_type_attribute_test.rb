require "test_helper"

class RelationshipTypeAttributeTest < ActiveSupport::TestCase
  def build(**overrides)
    RelationshipTypeAttribute.new({ relationship_type: relationship_types(:bare_relation),
                                    name: "note", value_type: "string" }.merge(overrides))
  end

  test "requires a name" do
    assert_not build(name: nil).valid?
  end

  test "rejects a value type outside the four allowed" do
    attribute = build(value_type: "boolean")

    assert_not attribute.valid?
    assert_match(/must be one of/, attribute.errors.full_messages.to_sentence)
  end

  test "accepts each of the four allowed value types" do
    RelationshipTypeAttribute::VALUE_TYPES.each do |value_type|
      assert build(name: "attr_#{value_type}", value_type: value_type).valid?,
             "#{value_type} should be a valid value type"
    end
  end

  test "rejects a duplicate name within the same type but allows it across types" do
    assert_not build(relationship_type: relationship_types(:powers), name: "stage").valid?
    assert build(relationship_type: relationship_types(:bare_relation), name: "stage").valid?
  end

  # The project is derivable through the type, so the stored copy is pinned to
  # it rather than being a second thing that can be set independently.
  test "takes its project from its relationship type" do
    attribute = build
    attribute.valid?

    assert_equal projects(:apollo), attribute.project
  end

  test "is invalid when its project contradicts its relationship type" do
    assert_not build(project: projects(:gemini)).valid?
  end
end
