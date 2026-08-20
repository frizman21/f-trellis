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

      assert_equal "Rocketdyne", by_name["manufacturer"]
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
      post project_entities_path(@project), params: { entity: { name: "New Engine", entity_type_id: entity_types(:rocket_engine).id } }
    end

    assert_redirected_to edit_project_entity_path(@project, Entity.order(:id).last)
  end

  test "create without a type creates nothing" do
    assert_no_difference -> { Entity.count } do
      post project_entities_path(@project), params: { entity: { name: "Nameless", entity_type_id: nil } }
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
    existing = entity_attribute_values(:f1_manufacturer)

    patch project_entity_path(@project, entity), params: {
      entity: { name: entity.name,
                entity_attribute_values_attributes: {
                  "0" => { id: existing.id, entity_type_attribute_id: existing.entity_type_attribute_id,
                           value: "Aerojet Rocketdyne" }
                } }
    }

    assert_equal "Aerojet Rocketdyne", entity.reload.value_for("manufacturer")
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

  # Soft: the row stays and the list stops showing it.
  test "destroy soft-deletes the entity" do
    assert_no_difference -> { Entity.count } do
      assert_difference -> { Entity.kept.count }, -1 do
        delete project_entity_path(@project, entities(:bare))
      end
    end

    assert_redirected_to project_path(@project)
    assert_predicate entities(:bare).reload, :discarded?
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
         params: { entity: { name: "New Engine", entity_type_id: entity_types(:rocket_engine).id } }

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
           params: { entity: { name: "Wrong Project", entity_type_id: entity_types(:gemini_capsule).id } }
    end

    assert_response :unprocessable_entity
  end

  # --- the project header ----------------------------------------------------


  test "the relationship table names the kind of each edge" do
    get project_entity_path(@project, entities(:f1))

    assert_response :success
    assert_select "td", text: "Powers"
  end


  # --- citing a source -------------------------------------------------------

  test "create records a citation for the entity when a source is chosen" do
    assert_difference -> { EntityExtractionRun.count }, 1 do
      post project_entities_path(@project), params: {
        entity: { name: "Cited Engine", entity_type_id: entity_types(:rocket_engine).id,
                  entity_extraction_runs_attributes: { "0" => { source_id: sources(:one).id, confidence: "80" } } }
      }
    end

    citation = Entity.order(:id).last.entity_extraction_runs.sole

    assert_equal sources(:one), citation.source
    assert_equal 80, citation.confidence
  end

  # Citing is optional, so a blank search box is not an error.
  test "create records no citation when no source is chosen" do
    assert_difference -> { Entity.count }, 1 do
      assert_no_difference -> { EntityExtractionRun.count } do
        post project_entities_path(@project), params: {
          entity: { name: "Uncited Engine", entity_type_id: entity_types(:rocket_engine).id,
                    entity_extraction_runs_attributes: { "0" => { source_id: "", confidence: "100" } } }
        }
      end
    end
  end

  test "create rejects a confidence outside 1..100 and records nothing" do
    assert_no_difference [ -> { Entity.count }, -> { EntityExtractionRun.count } ] do
      post project_entities_path(@project), params: {
        entity: { name: "Cited Engine", entity_type_id: entity_types(:rocket_engine).id,
                  entity_extraction_runs_attributes: { "0" => { source_id: sources(:one).id, confidence: "101" } } }
      }
    end

    assert_response :unprocessable_entity
  end

  # The citation belongs to the value, not to the entity: different facts about
  # one thing can come from different pages.
  test "update cites a source against a specific attribute value" do
    entity = entities(:f1)
    chambers = entity_type_attributes(:engine_chambers)

    assert_difference -> { EntityAttributeValueExtractionRun.count }, 1 do
      assert_no_difference -> { EntityExtractionRun.count } do
        patch project_entity_path(@project, entity), params: {
          entity: { entity_attribute_values_attributes: {
            "0" => { entity_type_attribute_id: chambers.id, value: "5",
                     entity_attribute_value_extraction_runs_attributes: {
                       "0" => { source_id: sources(:one).id, confidence: "60" }
                     } }
          } }
        }
      end
    end

    value = entity.reload.entity_attribute_values.find_by(entity_type_attribute: chambers)

    assert_equal sources(:one), value.entity_attribute_value_extraction_runs.sole.source
    assert_equal 60, value.entity_attribute_value_extraction_runs.sole.confidence
  end

  test "a blank source with a confidence filled in records nothing" do
    entity = entities(:f1)

    assert_no_difference -> { EntityAttributeValueExtractionRun.count } do
      patch project_entity_path(@project, entity), params: {
        entity: { entity_attribute_values_attributes: {
          "0" => { entity_type_attribute_id: entity_type_attributes(:engine_chambers).id, value: "5",
                   entity_attribute_value_extraction_runs_attributes: {
                     "0" => { source_id: "", confidence: "60" }
                   } }
        } }
      }
    end
  end

  test "show displays what each fact is cited from, with its confidence" do
    EntityAttributeValueExtractionRun.create!(
      entity_attribute_value: entity_attribute_values(:f1_manufacturer),
      source: sources(:one), confidence: 42,
      extraction_run: an_extraction_run(project: @project, source: sources(:one))
    )

    get project_entity_path(@project, entities(:f1))

    assert_response :success
    assert_select "th", text: "Cited from"
    assert_match(/42%/, response.body)
  end

  test "the entity form offers a source search field" do
    get new_project_entity_path(@project)

    assert_select "[data-controller=?]", "source-search"
    assert_select "input[name=?]", "entity[entity_extraction_runs_attributes][0][source_id]"
  end

  # --- the relationship picker respects the declared ends --------------------



  # What the narrowing controller reads to hide entities that cannot be the far
  # end of the chosen kind.

  # --- the relationships table -----------------------------------------------

  test "the relationships table leads with the kind of relationship" do
    get project_entity_path(@project, entities(:f1))

    assert_response :success
    assert_select "h2", text: "Relationships"
    headers = css_select("table").last.css("th").map { |th| th.text.strip }

    # The far end's name and type are one fact, so one column; plus a column per
    # relationship attribute the type asks to show.
    # The far end's name and type are one fact, so one column; then a column per
    # relationship attribute the type asks to show, in name order.
    assert_equal [ "Relationship", "Direction", "Entity",
                   "certified_on", "engine_count", "stage", "thrust_share", "" ], headers
  end

  test "a row reads type, direction, other entity, other entity's type" do
    get project_entity_path(@project, entities(:f1))

    cells = css_select("table").last.css("tbody tr").first.css("td").map { |td| td.text.strip }

    assert_equal "Powers", cells[0]
    assert_equal "→ to", cells[1]
    # Name and type share the cell.
    assert_match(/#{Regexp.escape(entities(:saturn_v).name)}/, cells[2])
    assert_match(/Launch Vehicle/, cells[2])
  end

  # A column reorder is exactly the edit that can silently swap two cells, so
  # the far-end link is re-asserted from both directions.
  test "the other entity is still the far end, from either side" do
    get project_entity_path(@project, entities(:f1))
    assert_select "a[href=?]", project_entity_path(@project, entities(:saturn_v))

    get project_entity_path(@project, entities(:saturn_v))
    assert_select "a[href=?]", project_entity_path(@project, entities(:f1))
    assert_select "table a[href=?]", project_entity_path(@project, entities(:saturn_v)), count: 0
  end

  test "the page offers no relationship form" do
    get project_entity_path(@project, entities(:f1))

    assert_select "select[name=?]", "relationship[relationship_type_id]", count: 0
    assert_select "select[name=?]", "relationship[to_entity_id]", count: 0
    assert_select "input[value=?]", "Add relationship", count: 0
  end

  test "an existing relationship can still be edited and removed" do
    get project_entity_path(@project, entities(:f1))

    assert_select "a[href=?]", edit_project_relationship_path(@project, relationships(:f1_powers_saturn_v))
    assert_select "form[action*=?]", project_relationship_path(@project, relationships(:f1_powers_saturn_v))
  end

  # --- retired attributes ----------------------------------------------------

  test "the edit form offers no field for a disabled attribute" do
    entity_type_attributes(:engine_chambers).update!(is_disabled: true)

    get edit_project_entity_path(@project, entities(:f1))

    assert_response :success
    assert_select "form label", { text: "chambers", count: 0 }
    assert_select "form label", text: "thrust_kn"
  end

  # Dropping a recorded fact from the screen because its attribute was retired
  # would be losing data from the page, so the value stays and is marked.
  test "show still displays a value recorded against a disabled attribute, marked" do
    entity_type_attributes(:engine_manufacturer).update!(is_disabled: true)

    get project_entity_path(@project, entities(:f1))

    assert_response :success
    assert_select "td", text: /Rocketdyne/
    assert_select ".badge", text: "disabled"
  end

  test "show omits a disabled attribute that holds no value" do
    entity_type_attributes(:engine_chambers).update!(is_disabled: true)

    get project_entity_path(@project, entities(:f1))

    assert_select "td", { text: /chambers/, count: 0 }
  end


  # --- the far end's cell ----------------------------------------------------

  test "the far end's cell links the entity and its type, from both ends" do
    get project_entity_path(@project, entities(:f1))

    assert_select "a[href=?]", project_entity_path(@project, entities(:saturn_v))
    assert_select "a[href=?]", project_typed_entities_path(@project, entity_types(:launch_vehicle).slug)

    get project_entity_path(@project, entities(:saturn_v))

    assert_select "a[href=?]", project_entity_path(@project, entities(:f1))
    assert_select "a[href=?]", project_typed_entities_path(@project, entity_types(:rocket_engine).slug)
  end

  # --- columns the type asks for ---------------------------------------------

  test "the relationships table shows a column for a displayed relationship attribute" do
    get project_entity_path(@project, entities(:f1))

    headers = css_select("table").last.css("th").map { |th| th.text.strip }
    assert_includes headers, "engine_count"

    cells = css_select("table").last.css("tbody tr").first.css("td").map { |td| td.text.strip }
    assert_equal "5", cells[headers.index("engine_count")]
  end

  test "an undisplayed relationship attribute is not a column" do
    relationship_type_attributes(:powers_engine_count).update!(is_displayed_on_index: false)

    get project_entity_path(@project, entities(:f1))

    headers = css_select("table").last.css("th").map { |th| th.text.strip }
    assert_not_includes headers, "engine_count"
  end

  # --- the name ---------------------------------------------------------------

  test "create records the name" do
    post project_entities_path(@project),
         params: { entity: { name: "F-1A", entity_type_id: entity_types(:rocket_engine).id } }

    assert_equal "F-1A", Entity.order(:id).last.name
  end

  test "create without a name creates nothing" do
    assert_no_difference -> { Entity.count } do
      post project_entities_path(@project),
           params: { entity: { name: "", entity_type_id: entity_types(:rocket_engine).id } }
    end

    assert_response :unprocessable_entity
  end

  test "update changes the name" do
    patch project_entity_path(@project, entities(:f1)), params: { entity: { name: "F-1B" } }

    assert_equal "F-1B", entities(:f1).reload.name
  end

  test "the forms ask for a name" do
    get new_project_entity_path(@project)
    assert_select "input[name=?]", "entity[name]"

    get edit_project_entity_path(@project, entities(:f1))
    assert_select "input[name=?][value=?]", "entity[name]", "Rocketdyne F-1"
  end

  # The type is what this entity is, not somewhere else to go.
  test "the entity page names its type without linking it" do
    get project_entity_path(@project, entities(:f1))

    assert_response :success
    assert_select "p.text-muted", text: "Rocket Engine"
    assert_select "a[href=?]", project_entity_type_path(@project, entity_types(:rocket_engine)), count: 0
  end

  # --- the run a person's own edit belongs to (#71) ---------------------------

  test "a hand-entered citation gets a manual run of its own" do
    assert_difference -> { ExtractionRun.count }, 1 do
      post project_entities_path(@project), params: {
        entity: { name: "By Hand", entity_type_id: entity_types(:rocket_engine).id,
                  entity_extraction_runs_attributes: { "0" => { source_id: sources(:one).id, confidence: "90" } } }
      }
    end

    citation = Entity.order(:id).last.entity_extraction_runs.sole
    run = citation.extraction_run

    assert_predicate run, :manual?
    assert_equal sources(:one), run.source
    assert_equal @project, run.project
  end

  # Nothing was cited, so nothing was seen, so there is no sighting to record.
  test "a submission that cites nothing creates no run" do
    assert_no_difference -> { ExtractionRun.count } do
      post project_entities_path(@project), params: {
        entity: { name: "Uncited", entity_type_id: entity_types(:rocket_engine).id,
                  entity_extraction_runs_attributes: { "0" => { source_id: "", confidence: "100" } } }
      }
    end
  end

  # Each save is its own sighting: recording the same page again is a second
  # observation, not a correction of the first.
  test "editing the same entity twice records two sightings" do
    post project_entities_path(@project), params: {
      entity: { name: "Twice Seen", entity_type_id: entity_types(:rocket_engine).id,
                entity_extraction_runs_attributes: { "0" => { source_id: sources(:one).id, confidence: "90" } } }
    }
    entity = Entity.order(:id).last

    assert_difference [ -> { ExtractionRun.count }, -> { EntityExtractionRun.count } ], 1 do
      patch project_entity_path(@project, entity), params: {
        entity: { entity_extraction_runs_attributes: { "0" => { source_id: sources(:two).id, confidence: "70" } } }
      }
    end

    assert_equal 2, entity.reload.entity_extraction_runs.count
  end

  # A failed save must not leave a run behind claiming an edit that never
  # happened, which is why the two are in one transaction.
  test "a rejected submission leaves no run behind" do
    assert_no_difference [ -> { ExtractionRun.count }, -> { Entity.count } ] do
      post project_entities_path(@project), params: {
        entity: { name: "", entity_type_id: entity_types(:rocket_engine).id,
                  entity_extraction_runs_attributes: { "0" => { source_id: sources(:one).id, confidence: "90" } } }
      }
    end
  end

  # The sentinel exists to satisfy a foreign key, not to be chosen.
  test "the manual sentinel is offered by no picker" do
    ExtractionRun.manual_model

    assert_not_includes Model.selectable, Model.find_by(provider: "manual")
  end
end
