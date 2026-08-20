require "test_helper"

# Where one recorded fact came from. Four kinds of fact can be cited and the
# question is the same for all four, so each kind is asserted rather than
# trusting that one standing in for the rest — a kind that resolved to the wrong
# table would show somebody else's provenance, which is worse than showing none.
class PedigreesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:apollo)
    @run = an_extraction_run(project: @project, source: sources(:one))
  end

  def cite(klass, owner, source: sources(:one), run: @run, confidence: 100)
    klass.create!(owner.merge(source: source, extraction_run: run, confidence: confidence))
  end

  test "an entity's pedigree lists the source and the run that saw it" do
    cite EntityExtractionRun, { entity: entities(:f1) }

    get project_pedigree_path(@project, kind: "entity", id: entities(:f1).id)

    assert_response :success
    assert_match sources(:one).url, response.body
    assert_match @run.model.model_id, response.body
  end

  test "an attribute value's pedigree names the fact it is about" do
    value = entity_attribute_values(:f1_manufacturer)
    cite EntityAttributeValueExtractionRun, { entity_attribute_value: value }

    get project_pedigree_path(@project, kind: "entity-value", id: value.id)

    assert_response :success
    # Bookmarkable, so it has to say what it is the pedigree of.
    assert_match value.entity.name, response.body
    assert_match value.entity_type_attribute.name, response.body
  end

  test "a relationship's pedigree works" do
    relationship = relationships(:f1_powers_saturn_v)
    cite RelationshipExtractionRun, { relationship: relationship }

    get project_pedigree_path(@project, kind: "relationship", id: relationship.id)

    assert_response :success
    assert_match relationship.relationship_type.name, response.body
  end

  test "a relationship value's pedigree works" do
    value = relationship_type_values(:f1_powers_saturn_v_engine_count)
    cite RelationshipTypeValueExtractionRun, { relationship_type_value: value }

    get project_pedigree_path(@project, kind: "relationship-value", id: value.id)

    assert_response :success
    assert_match value.relationship_type_attribute.name, response.body
  end

  # The point of #71 surfacing on a screen: the same page seen by two runs is
  # two sightings, and the page has to show both or the column counting them is
  # lying.
  test "two runs over the same source are two rows" do
    entity = entities(:f1)
    cite EntityExtractionRun, { entity: entity }
    cite EntityExtractionRun, { entity: entity },
         run: an_extraction_run(project: @project, source: sources(:one))

    get project_pedigree_path(@project, kind: "entity", id: entity.id)

    assert_response :success
    assert_select "tbody tr", count: 2
    # Whitespace-tolerant: the count spans a line break in the template.
    assert_match(/Seen 2 times\s+across 1 source/, response.body)
    assert_match(/more than once/, response.body)
  end

  test "a fact recorded by hand says so rather than naming a model" do
    entity = entities(:f1)
    cite EntityExtractionRun, { entity: entity },
         run: ExtractionRun.manual(project: @project, source: sources(:one))

    get project_pedigree_path(@project, kind: "entity", id: entity.id)

    assert_response :success
    assert_match(/Entered by hand/, response.body)
  end

  test "a fact citing nothing says so rather than showing an empty table" do
    get project_pedigree_path(@project, kind: "entity", id: entities(:bare).id)

    assert_response :success
    assert_match(/Nothing records where this came from/, response.body)
    assert_select "tbody tr", count: 0
  end

  # --- scoping ---------------------------------------------------------------

  # Every citable record carries project_id, so an id from elsewhere is a 404 by
  # construction rather than by a check someone has to remember to write.
  test "another project's entity is not found under this project" do
    get project_pedigree_path(@project, kind: "entity", id: entities(:gemini_capsule).id)

    assert_response :not_found
  end

  # The kind is a path segment, so it is checked against a list rather than used
  # to name a class.
  test "an unknown kind is not found" do
    get project_pedigree_path(@project, kind: "sources", id: entities(:f1).id)

    assert_response :not_found
  end
end
