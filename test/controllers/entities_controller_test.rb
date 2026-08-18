require "test_helper"

class EntitiesControllerTest < ActionDispatch::IntegrationTest
  setup { @project = projects(:apollo) }

  # --- index -----------------------------------------------------------------



  # --- show: the attributes table -------------------------------------------

  test "show renders one attribute row per attribute of the type" do
    get project_entity_path(@project, entities(:f1))

    assert_response :success
    assert_select "h1", "Rocketdyne F-1"
    # Four attributes on Rocket Engine, plus the header row.
    assert_select "table:first-of-type tbody tr", 4
  end

  test "show renders each attribute's name in the first column and value in the second" do
    get project_entity_path(@project, entities(:f1))

    assert_select "table:first-of-type tbody tr" do |rows|
      cells = rows.map { |row| row.css("td").map { |td| td.text.strip } }
      by_name = cells.to_h { |name, value| [ name.split.first, value ] }

      assert_equal "Rocketdyne F-1", by_name["name"]
      assert_equal "6770.0", by_name["thrust_kn"]
      # Declared on the type, never recorded: a blank row rather than a missing
      # one, so the page shows the shape of the type as well as the content.
      assert_equal "", by_name["chambers"]
    end
  end

  test "show renders an empty state when the type declares no attributes" do
    get project_entity_path(@project, entities(:bare))

    assert_response :success
    assert_match(/defines no attributes yet/, response.body)
  end

  # --- show: the relationships table -----------------------------------------

  test "show lists a relationship where the entity is the from end, linking to the other entity" do
    get project_entity_path(@project, entities(:f1))

    assert_response :success
    assert_select "a[href=?]", project_entity_path(@project, entities(:saturn_v))
  end

  test "show lists a relationship where the entity is the to end, linking to the other entity" do
    get project_entity_path(@project, entities(:saturn_v))

    assert_response :success
    # The far end from Saturn V is the F-1, not itself. Asserted from this side
    # too because linking back to the current page is the easy mistake here.
    assert_select "a[href=?]", project_entity_path(@project, entities(:f1))
    assert_select "a[href=?]", project_entity_path(@project, entities(:saturn_v)), count: 0
  end

  test "show reports the direction of each relationship" do
    get project_entity_path(@project, entities(:f1))
    assert_match(/→ to/, response.body)

    get project_entity_path(@project, entities(:saturn_v))
    assert_match(/← from/, response.body)
  end

  test "show renders an empty state when the entity has no relationships" do
    get project_entity_path(@project, entities(:bare))

    assert_response :success
    assert_match(/No relationships yet/, response.body)
  end

  # --- create ----------------------------------------------------------------

  test "new renders the type picker" do
    get new_project_entity_path(@project)

    assert_response :success
    assert_select "select[name=?]", "entity[entity_type_id]"
  end

  test "create makes an entity and sends you on to fill in its attributes" do
    assert_difference -> { Entity.count }, 1 do
      post project_entities_path(@project), params: { entity: { entity_type_id: entity_types(:rocket_engine).id } }
    end

    assert_redirected_to edit_project_entity_path(@project, Entity.order(:id).last)
  end

  test "create without a type creates nothing" do
    assert_no_difference -> { Entity.count } do
      post project_entities_path(@project), params: { entity: { entity_type_id: nil } }
    end

    assert_response :unprocessable_entity
  end

  # --- edit and update -------------------------------------------------------

  test "edit offers a field for every attribute of the type" do
    get edit_project_entity_path(@project, entities(:f1))

    assert_response :success
    # One value input per attribute of the type — the hidden id and
    # entity_type_attribute_id fields are counted separately on purpose, so this
    # asserts what a person can fill in rather than how many inputs exist.
    assert_select "form input[name*=?]", "[value]", count: 4
    assert_select "form label", text: "chambers"
  end

  test "update records a value for an attribute that had none" do
    entity = entities(:f1)
    chambers = entity_type_attributes(:engine_chambers)

    patch project_entity_path(@project, entity), params: {
      entity: { entity_attribute_values_attributes: {
        "0" => { entity_type_attribute_id: chambers.id, value: "5" }
      } }
    }

    assert_redirected_to project_entity_path(@project, entity)
    assert_equal 5, entity.reload.value_for("chambers")
  end

  test "update changes a value that already existed" do
    entity = entities(:f1)
    existing = entity_attribute_values(:f1_name)

    patch project_entity_path(@project, entity), params: {
      entity: { entity_attribute_values_attributes: {
        "0" => { id: existing.id, entity_type_attribute_id: existing.entity_type_attribute_id,
                 value: "Rocketdyne F-1A" }
      } }
    }

    assert_equal "Rocketdyne F-1A", entity.reload.value_for("name")
  end

  test "update rejects a value that does not fit its declared type" do
    entity = entities(:f1)
    chambers = entity_type_attributes(:engine_chambers)

    patch project_entity_path(@project, entity), params: {
      entity: { entity_attribute_values_attributes: {
        "0" => { entity_type_attribute_id: chambers.id, value: "not a number" }
      } }
    }

    assert_response :unprocessable_entity
    assert_nil entity.reload.value_for("chambers")
  end

  test "a blank field for an unrecorded attribute records nothing" do
    entity = entities(:f1)
    chambers = entity_type_attributes(:engine_chambers)

    assert_no_difference -> { EntityAttributeValue.count } do
      patch project_entity_path(@project, entity), params: {
        entity: { entity_attribute_values_attributes: {
          "0" => { entity_type_attribute_id: chambers.id, value: "" }
        } }
      }
    end
  end

  # --- destroy ---------------------------------------------------------------

  test "destroy removes the entity" do
    assert_difference -> { Entity.count }, -1 do
      delete project_entity_path(@project, entities(:bare))
    end

    assert_redirected_to data_project_path(@project)
  end

  # --- scoping ---------------------------------------------------------------
  #
  # Asserted as isolation rather than as "the page rendered". A scoped screen
  # that still shows another project's rows renders perfectly well.


  test "another project's entity is not found under this project" do
    get project_entity_path(@project, entities(:gemini_capsule))

    assert_response :not_found
  end

  test "another project's entity cannot be edited under this project" do
    get edit_project_entity_path(@project, entities(:gemini_capsule))

    assert_response :not_found
  end

  test "another project's entity cannot be destroyed under this project" do
    delete project_entity_path(@project, entities(:gemini_capsule))

    assert_response :not_found

    assert Entity.exists?(entities(:gemini_capsule).id)
  end

  test "create assigns the project from the url" do
    post project_entities_path(@project),
         params: { entity: { entity_type_id: entity_types(:rocket_engine).id } }

    assert_equal @project, Entity.order(:id).last.project
  end

  test "the type picker offers only this project's entity types" do
    get new_project_entity_path(@project)

    assert_select "select[name=?] option", "entity[entity_type_id]" do |options|
      offered = options.map { |o| o["value"] }.compact_blank.map(&:to_i)

      assert_equal @project.entity_types.pluck(:id).sort, offered.sort
      assert_not_includes offered, entity_types(:gemini_capsule).id
    end
  end

  test "an entity cannot be typed by another project's ontology" do
    assert_no_difference -> { Entity.count } do
      post project_entities_path(@project),
           params: { entity: { entity_type_id: entity_types(:gemini_capsule).id } }
    end

    assert_response :unprocessable_entity
  end

  # --- the project header ----------------------------------------------------


  test "the relationship table names the kind of each edge" do
    get project_entity_path(@project, entities(:f1))

    assert_response :success
    assert_select "td", text: "Powers"
  end

  test "the relationship picker offers only this project's relationship types" do
    get project_entity_path(@project, entities(:f1))

    assert_select "select[name=?] option", "relationship[relationship_type_id]" do |options|
      offered = options.map { |o| o["value"] }.compact_blank.map(&:to_i)

      assert_equal @project.relationship_types.pluck(:id).sort, offered.sort
      assert_not_includes offered, relationship_types(:gemini_docks).id
    end
  end

  # --- citing a source -------------------------------------------------------

  test "create records a citation for the entity when a source is chosen" do
    assert_difference -> { EntitySource.count }, 1 do
      post project_entities_path(@project), params: {
        entity: { entity_type_id: entity_types(:rocket_engine).id,
                  entity_sources_attributes: { "0" => { source_id: sources(:one).id, confidence: "80" } } }
      }
    end

    citation = Entity.order(:id).last.entity_sources.sole

    assert_equal sources(:one), citation.source
    assert_equal 80, citation.confidence
  end

  # Citing is optional, so a blank search box is not an error.
  test "create records no citation when no source is chosen" do
    assert_difference -> { Entity.count }, 1 do
      assert_no_difference -> { EntitySource.count } do
        post project_entities_path(@project), params: {
          entity: { entity_type_id: entity_types(:rocket_engine).id,
                    entity_sources_attributes: { "0" => { source_id: "", confidence: "100" } } }
        }
      end
    end
  end

  test "create rejects a confidence outside 1..100 and records nothing" do
    assert_no_difference [ -> { Entity.count }, -> { EntitySource.count } ] do
      post project_entities_path(@project), params: {
        entity: { entity_type_id: entity_types(:rocket_engine).id,
                  entity_sources_attributes: { "0" => { source_id: sources(:one).id, confidence: "101" } } }
      }
    end

    assert_response :unprocessable_entity
  end

  # The citation belongs to the value, not to the entity: different facts about
  # one thing can come from different pages.
  test "update cites a source against a specific attribute value" do
    entity = entities(:f1)
    chambers = entity_type_attributes(:engine_chambers)

    assert_difference -> { EntityAttributeValueSource.count }, 1 do
      assert_no_difference -> { EntitySource.count } do
        patch project_entity_path(@project, entity), params: {
          entity: { entity_attribute_values_attributes: {
            "0" => { entity_type_attribute_id: chambers.id, value: "5",
                     entity_attribute_value_sources_attributes: {
                       "0" => { source_id: sources(:one).id, confidence: "60" }
                     } }
          } }
        }
      end
    end

    value = entity.reload.entity_attribute_values.find_by(entity_type_attribute: chambers)

    assert_equal sources(:one), value.entity_attribute_value_sources.sole.source
    assert_equal 60, value.entity_attribute_value_sources.sole.confidence
  end

  test "a blank source with a confidence filled in records nothing" do
    entity = entities(:f1)

    assert_no_difference -> { EntityAttributeValueSource.count } do
      patch project_entity_path(@project, entity), params: {
        entity: { entity_attribute_values_attributes: {
          "0" => { entity_type_attribute_id: entity_type_attributes(:engine_chambers).id, value: "5",
                   entity_attribute_value_sources_attributes: {
                     "0" => { source_id: "", confidence: "60" }
                   } }
        } }
      }
    end
  end

  test "show displays what each fact is cited from, with its confidence" do
    EntityAttributeValueSource.create!(entity_attribute_value: entity_attribute_values(:f1_name),
                                       source: sources(:one), confidence: 42)

    get project_entity_path(@project, entities(:f1))

    assert_response :success
    assert_select "th", text: "Cited from"
    assert_match(/42%/, response.body)
  end

  test "the entity form offers a source search field" do
    get new_project_entity_path(@project)

    assert_select "[data-controller=?]", "source-search"
    assert_select "input[name=?]", "entity[entity_sources_attributes][0][source_id]"
  end

  # --- the relationship picker respects the declared ends --------------------

  test "the picker offers only types that can start at this entity's type" do
    get project_entity_path(@project, entities(:f1))

    assert_select "select[name=?] option", "relationship[relationship_type_id]" do |options|
      offered = options.map { |o| o["value"] }.compact_blank.map(&:to_i)
      expected = @project.relationship_types
                         .where(from_entity_type_id: entities(:f1).entity_type_id).pluck(:id)

      assert_equal expected.sort, offered.sort
    end
  end

  test "an entity no type can start at is told so rather than shown a dead picker" do
    get project_entity_path(@project, entities(:saturn_v))

    assert_response :success
    assert_select "select[name=?]", "relationship[relationship_type_id]", count: 0
    assert_match(/starts at a Launch Vehicle/, response.body)
  end

  # What the narrowing controller reads to hide entities that cannot be the far
  # end of the chosen kind.
  test "the picker carries the entity type ids the narrowing needs" do
    get project_entity_path(@project, entities(:f1))

    assert_select "select[name=?][data-relationship-form-target=?]",
                  "relationship[relationship_type_id]", "type"
    assert_select "select[name=?] option[data-entity-type-id=?]",
                  "relationship[to_entity_id]", entities(:saturn_v).entity_type_id.to_s
    assert_select "select[name=?] option[data-to-entity-type-id]",
                  "relationship[relationship_type_id]"
  end
end
