require "test_helper"

# Turning a reply into records. Tested against JSON strings with no model in the
# picture: what these rules do is the substance of the change, and a model would
# only make them harder to provoke.
class ExtractionApplierTest < ActiveSupport::TestCase
  setup do
    @project = projects(:apollo)
    @source = sources(:one)
    ProjectSource.create!(project: @project, source: @source)
    @model = Model.create!(provider: "anthropic", model_id: "claude-test",
                           name: "C", last_seen_at: Time.current)
  end

  def apply(json)
    run = ExtractionRun.create!(project: @project, source: @source, model: @model,
                                status: "complete", response: json)
    ExtractionApplier.new(run).call
  end

  def entity_json(**overrides)
    { "id" => "e1", "name" => "Merlin 1D", "type" => "Rocket Engine" }.merge(overrides)
  end

  def reply(entities: [], relationships: [])
    { "entities" => entities, "relationships" => relationships }.to_json
  end

  # --- creating --------------------------------------------------------------

  test "creates an entity with its values and cites the source for both" do
    summary = apply reply(entities: [ entity_json("attributes" => { "thrust_kn" => "845.0",
                                                                    "chambers" => "1" }) ])

    entity = @project.entities.kept.find_by(name: "Merlin 1D")

    assert_equal 1, summary.dig("entities", "created")
    assert_equal "Rocket Engine", entity.entity_type.name
    assert_in_delta 845.0, entity.value_for("thrust_kn")
    assert_equal 1, entity.value_for("chambers")

    assert_equal @source, entity.entity_sources.sole.source
    assert_equal ExtractionApplier::CONFIDENCE, entity.entity_sources.sole.confidence
    entity.entity_attribute_values.each do |value|
      assert_equal @source, value.entity_attribute_value_sources.sole.source
    end
  end

  test "creates a relationship between entities the same reply created" do
    summary = apply reply(
      entities: [ entity_json, { "id" => "e2", "name" => "Falcon 9", "type" => "Launch Vehicle" } ],
      relationships: [ { "type" => "Powers", "from" => "e1", "to" => "e2" } ]
    )

    edge = @project.relationships.kept.last

    assert_equal 1, summary.dig("relationships", "created")
    assert_equal "Merlin 1D", edge.from_entity.name
    assert_equal "Falcon 9", edge.to_entity.name
    assert_equal @source, edge.relationship_sources.sole.source
  end

  # --- matching --------------------------------------------------------------

  test "matches an existing entity rather than creating a second one" do
    assert_no_difference -> { Entity.count } do
      summary = apply reply(entities: [ entity_json("name" => "Rocketdyne F-1") ])

      assert_equal 1, summary.dig("entities", "matched")
      assert_equal 0, summary.dig("entities", "created")
    end
  end

  test "matching is case-insensitive" do
    assert_no_difference -> { Entity.count } do
      apply reply(entities: [ entity_json("name" => "rocketdyne f-1") ])
    end
  end

  # A name is only a match within the same type; two kinds of thing may share one.
  test "a name matching under a different type creates a new entity" do
    assert_difference -> { Entity.count }, 1 do
      apply reply(entities: [ entity_json("name" => "Rocketdyne F-1", "type" => "Launch Vehicle") ])
    end
  end

  test "applying the same reply twice creates nothing the second time" do
    json = reply(entities: [ entity_json("attributes" => { "thrust_kn" => "845.0" }) ],
                 relationships: [])
    apply json

    assert_no_difference [ -> { Entity.count }, -> { EntityAttributeValue.count },
                           -> { EntitySource.count } ] do
      apply json
    end
  end

  # --- skipping, each reason on its own --------------------------------------
  #
  # One "it skipped something" test would pass while five of the six reasons
  # were broken.

  test "skips an entity whose type the project does not define" do
    summary = apply reply(entities: [ entity_json("type" => "Agency") ])

    assert_equal 0, summary.dig("entities", "created")
    assert_match(/no entity type named/, summary.dig("entities", "skipped").sole["reason"])
  end

  test "skips an entity with no name" do
    summary = apply reply(entities: [ entity_json("name" => "") ])

    assert_match(/no name/, summary.dig("entities", "skipped").sole["reason"])
  end

  test "skips an attribute the type does not declare" do
    summary = apply reply(entities: [ entity_json("attributes" => { "colour" => "red" }) ])

    assert_equal 1, summary.dig("entities", "created")
    assert_match(/no active attribute named "colour"/, summary.dig("values", "skipped").sole["reason"])
  end

  test "skips a disabled attribute" do
    entity_type_attributes(:engine_thrust).update!(is_disabled: true)

    summary = apply reply(entities: [ entity_json("attributes" => { "thrust_kn" => "845.0" }) ])

    assert_equal 1, summary.dig("values", "skipped").size
    assert_nil @project.entities.kept.find_by(name: "Merlin 1D").value_for("thrust_kn")
  end

  test "skips a value that will not cast to its declared type" do
    summary = apply reply(entities: [ entity_json("attributes" => { "first_flight" => "sometime in the sixties" }) ])

    assert_equal 1, summary.dig("values", "skipped").size
    assert_equal 0, summary.dig("values", "created")
  end

  test "skips a relationship whose type the project does not define" do
    summary = apply reply(entities: [ entity_json ],
                          relationships: [ { "type" => "Invented", "from" => "e1", "to" => "e1" } ])

    assert_match(/no relationship type named/, summary.dig("relationships", "skipped").sole["reason"])
  end

  test "skips a relationship whose ends contradict its type" do
    summary = apply reply(
      entities: [ entity_json, { "id" => "e2", "name" => "Falcon 9", "type" => "Launch Vehicle" } ],
      # Powers runs engine -> vehicle; this is the other way round.
      relationships: [ { "type" => "Powers", "from" => "e2", "to" => "e1" } ]
    )

    assert_equal 0, summary.dig("relationships", "created")
    assert_match(/joins a Rocket Engine to a Launch Vehicle/, summary.dig("relationships", "skipped").sole["reason"])
  end

  # Resolved in the reply's own id map, not searched for in the database.
  test "skips a relationship end naming an id the reply never defined" do
    summary = apply reply(entities: [ entity_json ],
                          relationships: [ { "type" => "Powers", "from" => "e1", "to" => "ghost" } ])

    assert_match(/never defined/, summary.dig("relationships", "skipped").sole["reason"])
  end

  # --- conflicts -------------------------------------------------------------

  # Silently keeping the value without adding the citation is the plausible
  # half-implementation, so all three are asserted.
  test "a conflicting value is kept, cited, and reported" do
    existing = entity_attribute_values(:f1_thrust)
    stored = existing.value

    summary = apply reply(entities: [ entity_json("name" => "Rocketdyne F-1",
                                                  "attributes" => { "thrust_kn" => "9999.0" }) ])

    assert_in_delta stored, existing.reload.value
    assert_equal @source, existing.entity_attribute_value_sources.sole.source
    conflict = summary.dig("values", "conflicts").sole
    assert_equal "thrust_kn", conflict["attribute"]
    assert_equal "9999.0", conflict["offered"]
  end

  test "a value that agrees with the stored one is cited without a conflict" do
    existing = entity_attribute_values(:f1_thrust)

    summary = apply reply(entities: [ entity_json("name" => "Rocketdyne F-1",
                                                  "attributes" => { "thrust_kn" => existing.value.to_s }) ])

    assert_empty summary.dig("values", "conflicts")
    assert_equal @source, existing.reload.entity_attribute_value_sources.sole.source
  end

  # --- soft-deleted ----------------------------------------------------------

  # Deleting it was a decision; a later run should not quietly undo it.
  test "a match on a deleted entity is skipped, not resurrected" do
    entities(:f1).discard_with_relationships

    summary = apply reply(entities: [ entity_json("name" => "Rocketdyne F-1") ])

    assert_predicate entities(:f1).reload, :discarded?
    assert_equal 0, summary.dig("entities", "created")
    assert_match(/was deleted/, summary.dig("entities", "skipped").sole["reason"])
  end

  # --- nothing to apply ------------------------------------------------------

  test "a reply that does not parse writes nothing and says so" do
    assert_no_difference -> { Entity.count } do
      summary = apply "I could not find anything useful."

      assert_match(/not valid JSON/, summary["error"])
    end
  end

  test "an empty reply writes nothing" do
    assert_no_difference -> { Entity.count } do
      apply reply
    end
  end

  # A reply half-applied because the ninth entity failed would be worse than one
  # not applied at all, and would make re-running unsafe. Provoked rather than
  # assumed: the transaction is invisible until something raises inside it.
  test "a failure partway through writes nothing at all" do
    json = reply(entities: [ entity_json,
                             { "id" => "e2", "name" => "Falcon 9", "type" => "Launch Vehicle" } ])
    before = [ Entity.count, EntitySource.count ]

    original = Entity.instance_method(:save!)
    calls = 0
    # Keywords are passed through: ActiveRecord calls save! with them internally,
    # and a bare *args stub would raise before this test reached its own point.
    Entity.define_method(:save!) do |*args, **kwargs, &blk|
      calls += 1
      raise ActiveRecord::StatementInvalid, "boom" if calls > 1

      original.bind(self).call(*args, **kwargs, &blk)
    end

    raised = begin
      apply json
      false
    rescue ActiveRecord::StatementInvalid
      true
    ensure
      # Restored before the assertions, or teardown raises through them.
      Entity.define_method(:save!, original)
    end

    assert raised, "the stub should have blown up on the second entity"
    assert_equal before, [ Entity.count, EntitySource.count ],
                 "the first entity was left behind by a half-applied reply"
  end

  # --- deleted types (#66) ---------------------------------------------------

  test "does not create an entity of a deleted type" do
    entity_types(:rocket_engine).discard_with_entities

    summary = apply reply(entities: [ entity_json ])

    assert_equal 0, summary.dig("entities", "created").to_i
    assert_nil @project.entities.kept.find_by(name: "Merlin 1D")
  end

  test "does not create a relationship of a deleted type" do
    relationship_types(:powers).discard_with_relationships

    summary = apply reply(
      entities: [ entity_json,
                  { "id" => "e2", "name" => "Falcon 9", "type" => "Launch Vehicle" } ],
      relationships: [ { "type" => "Powers", "from" => "e1", "to" => "e2" } ]
    )

    assert_equal 0, summary.dig("relationships", "created").to_i
  end
end
