require "test_helper"

# The rule is on the concern both attribute models share, so it is asserted
# across both — a rule that held for entity attributes and quietly did not for
# relationship attributes is what a shared concern is meant to make impossible.
class AttributeDisablingTest < ActiveSupport::TestCase
  def cases
    [
      { used: entity_type_attributes(:engine_name),
        unused: entity_types(:rocket_engine).entity_type_attributes.create!(name: "spare", value_type: "string"),
        values: -> { EntityAttributeValue.count } },
      { used: relationship_type_attributes(:powers_engine_count),
        unused: relationship_types(:powers).relationship_type_attributes.create!(name: "spare", value_type: "string"),
        values: -> { RelationshipTypeValue.count } }
    ]
  end

  test "is_disabled defaults to false" do
    cases.each { |c| assert_not c[:unused].is_disabled?, "#{c[:unused].class} should start enabled" }
  end

  test "used? is false with nothing recorded and true with a value" do
    cases.each do |c|
      assert_not c[:unused].used?
      assert c[:used].used?
    end
  end

  test "an attribute nothing has been recorded against can be destroyed" do
    cases.each { |c| assert c[:unused].destroy, "#{c[:unused].class} should be destroyable" }
  end

  # The values are knowledge; the attribute is schema. Retiring the second must
  # not delete the first.
  test "a used attribute cannot be destroyed, and neither it nor its values go" do
    cases.each do |c|
      attribute = c[:used]

      assert_no_difference c[:values] do
        assert_not attribute.destroy, "#{attribute.class} should refuse to be destroyed"
      end

      assert attribute.class.exists?(attribute.id)
      assert_predicate attribute.errors, :any?
    end
  end

  test "disabling keeps the values recorded against it" do
    cases.each do |c|
      attribute = c[:used]

      assert_no_difference c[:values] do
        attribute.update!(is_disabled: true)
      end

      assert_predicate attribute.reload, :is_disabled?
    end
  end

  test "the active scope excludes disabled attributes and includes enabled ones" do
    cases.each do |c|
      attribute = c[:used]
      scope = attribute.class.where(id: attribute.id)

      assert_includes scope.active, attribute
      attribute.update!(is_disabled: true)
      assert_not_includes scope.active, attribute
    end
  end

  test "disabling round-trips" do
    attribute = entity_type_attributes(:engine_name)

    attribute.update!(is_disabled: true)
    assert_not attribute.reload.enabled?

    attribute.update!(is_disabled: false)
    assert_predicate attribute.reload, :enabled?
  end
end
