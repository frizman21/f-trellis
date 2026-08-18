require "test_helper"

# The F-DoD landscape is the proof that the generic ontology can express what
# the removed tier 1 model expressed. Asserting it here means a change that
# quietly breaks that expressiveness fails a test rather than a demo.
class FDodSeedTest < ActiveSupport::TestCase
  # The seed writes real rows, so it cannot run inside the fixture transaction
  # alongside fixtures for the same tables.
  self.use_transactional_tests = true

  def load_seed
    load Rails.root.join("db/seeds/f_dod.rb").to_s
  end

  setup do
    # Quietly: the seed reports what it wrote, which is noise in a test run.
    @silenced = capture_io { load_seed }
    @project = Project.find_by!(name: "F-DoD")
  end

  test "the project has exactly the six named entity types" do
    assert_equal %w[Contract Organization Part Person Science Technology],
                 @project.entity_types.pluck(:name).sort
  end

  # The name is a column (#28), so no type declares one as an attribute — that
  # would be two places for one fact.
  test "no entity type declares a name attribute" do
    @project.entity_types.each do |type|
      assert_not_includes type.entity_type_attributes.pluck(:name), "name",
                          "#{type.name} still declares a name attribute"
    end
  end

  test "every entity in the landscape has a name" do
    @project.entities.each do |entity|
      assert entity.name.present?, "entity #{entity.id} has no name"
    end
  end

  # The assertion that actually proves the landscape is expressible: every edge
  # satisfies the ends its type declares.
  test "every seeded relationship satisfies its type's declared ends" do
    invalid = @project.relationships.reject(&:valid?)

    assert_empty invalid.map { |r| "#{r.from_entity.name} -> #{r.to_entity.name}" }
  end

  test "every relationship type declares both of its ends within this project" do
    @project.relationship_types.each do |type|
      assert_equal @project.id, type.from_entity_type.project_id
      assert_equal @project.id, type.to_entity_type.project_id
    end
  end

  # The vocabulary the removed taxonomies carried, with the shapes they implied.
  test "the relationship vocabulary keeps the shapes the old model had" do
    expected = {
      "Employment" => %w[Person Organization],
      "Subsidiary" => %w[Organization Organization],
      "Composition" => %w[Part Part],
      "Enabling Principle" => %w[Science Technology],
      "Researcher" => %w[Person Science],
      "Awardee" => %w[Contract Organization],
      "Principal Investigator" => %w[Contract Person],
      "Developer" => %w[Organization Technology],
      "Deliverable" => %w[Contract Part]
    }

    expected.each do |name, (from, to)|
      type = @project.relationship_types.find_by!(name: name)

      assert_equal from, type.from_entity_type.name, "#{name} starts at the wrong type"
      assert_equal to, type.to_entity_type.name, "#{name} ends at the wrong type"
    end
  end

  # A value that failed to cast is stored as nothing at all, which is silent.
  test "every recorded value survived its cast" do
    @project.entity_attribute_values.each do |value|
      assert_not_nil value.value,
                     "#{value.entity_type_attribute.name} on entity #{value.entity_id} is empty"
    end
    @project.relationship_type_values.each do |value|
      assert_not_nil value.value,
                     "#{value.relationship_type_attribute.name} on relationship #{value.relationship_id} is empty"
    end
  end

  test "a contract's dates and value round-trip as datetime and float" do
    contract = @project.entities.find_by!(name: "Have Blue")

    assert_equal 1976, contract.value_for("start_date").year
    assert_in_delta 43_000_000.0, contract.value_for("value_usd")
  end

  test "running the seed twice creates nothing the second time" do
    counts = -> {
      [ EntityType, EntityTypeAttribute, Entity, EntityAttributeValue,
        RelationshipType, RelationshipTypeAttribute, Relationship,
        RelationshipTypeValue ].map { |k| k.unscoped.count }
    }
    before = counts.call

    capture_io { load_seed }

    assert_equal before, counts.call
  end
end
