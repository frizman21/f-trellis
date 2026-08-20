require "test_helper"

class EntityTypeTest < ActiveSupport::TestCase
  test "requires a name" do
    type = EntityType.new(name: nil)

    assert_not type.valid?
    assert_includes type.errors.attribute_names, :name
  end

  test "rejects a duplicate name, regardless of case" do
    assert_not EntityType.new(name: "rocket engine").valid?
  end

  test "a type with entities of it cannot be deleted" do
    type = entity_types(:rocket_engine)

    assert_not type.destroy
    assert_predicate type.errors, :any?
    assert EntityType.exists?(type.id)
  end

  test "a type with no entities can be deleted, and takes its attributes with it" do
    type = projects(:apollo).entity_types.create!(name: "Disposable")
    type.entity_type_attributes.create!(name: "whatever", value_type: "string")

    assert_difference -> { EntityTypeAttribute.count }, -1 do
      assert type.destroy
    end
  end

  # --- the address a type lists at -------------------------------------------

  test "the slug is the name, hyphenated and pluralised" do
    assert_equal "rocket-engines", entity_types(:rocket_engine).slug
    assert_equal "launch-vehicles", entity_types(:launch_vehicle).slug
  end

  # Recorded rather than guessed: what parameterize.pluralize does to a name
  # with capitals and punctuation is the actual contract of the URL.
  test "the slug handles capitals and punctuation" do
    type = projects(:apollo).entity_types.new(name: "MIT Lincoln Laboratory")

    assert_equal "mit-lincoln-laboratories", type.slug
  end

  # Two names, one address: the second type would be unreachable.
  test "a type whose slug matches another type's is invalid" do
    type = projects(:apollo).entity_types.new(name: "Rocket Engines")

    assert_not type.valid?
    assert_match(/same address/, type.errors.full_messages.to_sentence)
  end

  test "the same slug in another project is fine" do
    assert projects(:gemini).entity_types.new(name: "Rocket Engine").valid?
  end

  # A named route wins the match, so such a type would save and then 404.
  test "a type whose slug would shadow a real route is invalid" do
    EntityType::RESERVED_SLUGS.each do |reserved|
      type = projects(:apollo).entity_types.new(name: reserved.singularize.humanize)
      next unless type.slug == reserved

      assert_not type.valid?, "#{type.name} should be rejected"
      assert_match(/reserved/, type.errors.full_messages.to_sentence)
    end
  end

  test "a type named Entity is rejected, since entities is a route" do
    type = projects(:apollo).entity_types.new(name: "Entity")

    assert_equal "entities", type.slug
    assert_not type.valid?
    assert_match(/reserved/, type.errors.full_messages.to_sentence)
  end

  # --- soft delete (#66) -----------------------------------------------------

  test "discarding a type takes its entities and their relationships" do
    type = entity_types(:rocket_engine)

    type.discard_with_entities

    assert type.reload.discarded?
    assert entities(:f1).reload.discarded?
    assert relationships(:f1_powers_saturn_v).reload.discarded?
  end

  test "discarding a type takes the relationship types at either end" do
    # Bare Type is the `to` end of Bare Relation and the `from` end of nothing.
    # A cascade that only followed outgoing types would leave this one live.
    entity_types(:bare).discard_with_entities

    assert relationship_types(:bare_relation).reload.discarded?
  end

  test "discarding a type leaves another project's ontology alone" do
    entity_types(:rocket_engine).discard_with_entities

    assert_not entity_types(:gemini_capsule).reload.discarded?
    assert_not relationship_types(:gemini_docks).reload.discarded?
    assert_not entities(:gemini_capsule).reload.discarded?
  end

  test "a cascade does not restamp an already deleted entity" do
    already = entities(:unnamed_engine)
    already.discard!
    deleted_at = already.reload.deleted_at

    travel 1.hour do
      entity_types(:rocket_engine).discard_with_entities
    end

    assert_equal deleted_at, already.reload.deleted_at
  end

  test "a discarded type's name is free for a new one" do
    entity_types(:rocket_engine).discard_with_entities

    replacement = projects(:apollo).entity_types.new(name: "Rocket Engine")

    assert replacement.save, replacement.errors.full_messages.to_sentence
  end

  # The partial unique index is the half a validation-only test never reaches:
  # without it this is a PG::UniqueViolation rather than a clean insert.
  test "the database allows a discarded type's name to be reused" do
    entity_types(:rocket_engine).discard_with_entities

    assert_nothing_raised do
      projects(:apollo).entity_types.create!(name: "Rocket Engine")
    end
  end

  test "a discarded type's slug is free for a new one" do
    entity_types(:rocket_engine).discard_with_entities

    replacement = projects(:apollo).entity_types.new(name: "Rocket Engines")

    assert replacement.valid?, replacement.errors.full_messages.to_sentence
  end

  # The console guard the controller no longer reaches.
  test "a hard destroy is still refused while entities exist" do
    type = entity_types(:rocket_engine)

    assert_not type.destroy
    assert_includes type.errors.full_messages.to_sentence, "dependent entities exist"
  end
end
