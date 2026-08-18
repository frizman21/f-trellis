require "test_helper"

class RelationshipsControllerTest < ActionDispatch::IntegrationTest
  setup { @project = projects(:apollo) }

  test "create adds an edge and returns to the entity it was added from" do
    assert_difference -> { Relationship.count }, 1 do
      post project_relationships_path(@project), params: {
        relationship: { relationship_type_id: relationship_types(:bare_relation).id,
                      from_entity_id: entities(:f1).id, to_entity_id: entities(:bare).id }
      }
    end

    assert_redirected_to project_entity_path(@project, entities(:f1))
  end

  test "create refuses an edge from an entity to itself and says why" do
    assert_no_difference -> { Relationship.count } do
      post project_relationships_path(@project), params: {
        relationship: { relationship_type_id: relationship_types(:powers).id,
                      from_entity_id: entities(:f1).id, to_entity_id: entities(:f1).id }
      }
    end

    assert_redirected_to project_entity_path(@project, entities(:f1))
    assert flash[:alert].present?
  end

  test "destroy removes the edge and returns to the end it was removed from" do
    relationship = relationships(:f1_powers_saturn_v)

    assert_difference -> { Relationship.count }, -1 do
      # Removed from the `to` end, so it must come back here and not to the
      # `from` end the record happens to name first.
      delete project_relationship_path(@project, relationship, entity_id: entities(:saturn_v).id)
    end

    assert_redirected_to project_entity_path(@project, entities(:saturn_v))
  end

  test "destroy without an origin falls back to the from end" do
    relationship = relationships(:f1_powers_saturn_v)

    delete project_relationship_path(@project, relationship)

    assert_redirected_to project_entity_path(@project, entities(:f1))
  end

  test "a relationship cannot be created across projects" do
    assert_no_difference -> { Relationship.count } do
      post project_relationships_path(@project), params: {
        relationship: { relationship_type_id: relationship_types(:powers).id,
                        from_entity_id: entities(:f1).id, to_entity_id: entities(:gemini_capsule).id }
      }
    end

    assert flash[:alert].present?
  end

  test "create assigns the project from the url" do
    post project_relationships_path(@project), params: {
      relationship: { relationship_type_id: relationship_types(:bare_relation).id,
                      from_entity_id: entities(:f1).id, to_entity_id: entities(:bare).id }
    }

    assert_equal @project, Relationship.order(:id).last.project
  end

  # --- typing ----------------------------------------------------------------

  test "an edge cannot be created without a kind" do
    assert_no_difference -> { Relationship.count } do
      post project_relationships_path(@project), params: {
        relationship: { from_entity_id: entities(:f1).id, to_entity_id: entities(:bare).id }
      }
    end

    assert flash[:alert].present?
  end

  test "create assigns the relationship type" do
    post project_relationships_path(@project), params: {
      relationship: { relationship_type_id: relationship_types(:bare_relation).id,
                      from_entity_id: entities(:f1).id, to_entity_id: entities(:bare).id }
    }

    assert_equal relationship_types(:bare_relation), Relationship.order(:id).last.relationship_type
  end

  test "an edge cannot be typed by another project's relationship type" do
    assert_no_difference -> { Relationship.count } do
      post project_relationships_path(@project), params: {
        relationship: { relationship_type_id: relationship_types(:gemini_docks).id,
                        from_entity_id: entities(:f1).id, to_entity_id: entities(:bare).id }
      }
    end
  end

  # --- attribute values on an edge -------------------------------------------

  test "edit renders a field for every attribute of the edge's type" do
    get edit_project_relationship_path(@project, relationships(:f1_powers_saturn_v))

    assert_response :success
    assert_select "form input[name*=?]", "[value]", count: 4
    assert_select "form label", text: "stage"
  end

  test "update records a value for an attribute that had none" do
    relationship = relationships(:f1_powers_saturn_v)

    patch project_relationship_path(@project, relationship), params: {
      relationship: {
        relationship_type_id: relationship.relationship_type_id,
        relationship_type_values_attributes: {
          "0" => { relationship_type_attribute_id: relationship_type_attributes(:powers_stage).id,
                   value: "First" }
        }
      }
    }

    assert_redirected_to project_entity_path(@project, relationship.from_entity)
    stage = relationship.reload.relationship_type_values
                        .find_by(relationship_type_attribute: relationship_type_attributes(:powers_stage))
    assert_equal "First", stage.value
  end

  test "update rejects a value that does not fit its declared type" do
    relationship = relationships(:f1_powers_saturn_v)

    patch project_relationship_path(@project, relationship), params: {
      relationship: {
        relationship_type_id: relationship.relationship_type_id,
        relationship_type_values_attributes: {
          "0" => { relationship_type_attribute_id: relationship_type_attributes(:powers_thrust_share).id,
                   value: "not a number" }
        }
      }
    }

    assert_response :unprocessable_entity
  end

  test "a blank field for an unrecorded attribute records nothing" do
    relationship = relationships(:f1_powers_saturn_v)

    assert_no_difference -> { RelationshipTypeValue.count } do
      patch project_relationship_path(@project, relationship), params: {
        relationship: {
          relationship_type_id: relationship.relationship_type_id,
          relationship_type_values_attributes: {
            "0" => { relationship_type_attribute_id: relationship_type_attributes(:powers_stage).id,
                     value: "" }
          }
        }
      }
    end
  end

  # --- citing a source -------------------------------------------------------

  test "create records a citation for the edge when a source is chosen" do
    assert_difference -> { RelationshipSource.count }, 1 do
      post project_relationships_path(@project), params: {
        relationship: { relationship_type_id: relationship_types(:bare_relation).id,
                        from_entity_id: entities(:f1).id, to_entity_id: entities(:bare).id,
                        relationship_sources_attributes: {
                          "0" => { source_id: sources(:one).id, confidence: "75" }
                        } }
      }
    end

    citation = Relationship.order(:id).last.relationship_sources.sole

    assert_equal sources(:one), citation.source
    assert_equal 75, citation.confidence
  end

  test "create records no citation when no source is chosen" do
    assert_difference -> { Relationship.count }, 1 do
      assert_no_difference -> { RelationshipSource.count } do
        post project_relationships_path(@project), params: {
          relationship: { relationship_type_id: relationship_types(:bare_relation).id,
                          from_entity_id: entities(:f1).id, to_entity_id: entities(:bare).id,
                          relationship_sources_attributes: { "0" => { source_id: "", confidence: "100" } } }
        }
      end
    end
  end

  test "update cites a source against a specific attribute value of the edge" do
    relationship = relationships(:f1_powers_saturn_v)
    stage = relationship_type_attributes(:powers_stage)

    assert_difference -> { RelationshipTypeValueSource.count }, 1 do
      patch project_relationship_path(@project, relationship), params: {
        relationship: {
          relationship_type_id: relationship.relationship_type_id,
          relationship_type_values_attributes: {
            "0" => { relationship_type_attribute_id: stage.id, value: "First",
                     relationship_type_value_sources_attributes: {
                       "0" => { source_id: sources(:one).id, confidence: "55" }
                     } }
          }
        }
      }
    end

    value = relationship.reload.relationship_type_values.find_by(relationship_type_attribute: stage)

    assert_equal 55, value.relationship_type_value_sources.sole.confidence
  end

  test "the relationship edit form offers a source search field" do
    get edit_project_relationship_path(@project, relationships(:f1_powers_saturn_v))

    assert_select "[data-controller=?]", "source-search"
  end
end
