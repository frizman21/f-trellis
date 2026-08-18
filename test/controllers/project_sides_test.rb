require "test_helper"

# The two sides of a project, at the addresses named after them.
class ProjectSidesTest < ActionDispatch::IntegrationTest
  setup { @project = projects(:apollo) }

  # --- the ontology side -----------------------------------------------------

  test "ontology lists every entity type and every relationship type at once" do
    get structure_project_path(@project)

    assert_response :success
    assert_select "h1", text: "Entity Types"
    assert_select "h1", text: "Relationship Types"
    assert_select "a", text: "Rocket Engine"
    assert_select "a", text: "Powers"
  end

  test "ontology shows only this project's types" do
    get structure_project_path(@project)

    assert_select "a", text: "Capsule", count: 0
    assert_select "a", text: "Docks With", count: 0
  end

  # From and To are two facts about a type, so they are two columns.
  test "the relationship type table has From and To columns carrying the end names" do
    get structure_project_path(@project)

    assert_select "th", text: "From"
    assert_select "th", text: "To"
    assert_select "table:last-of-type tbody tr" do |rows|
      powers = rows.detect { |row| row.css("td").first.text.include?("Powers") }
      cells = powers.css("td").map { |cell| cell.text.strip }

      assert_equal "Rocket Engine", cells[1]
      assert_equal "Launch Vehicle", cells[2]
    end
  end

  test "ontology says so when a project has no types rather than showing empty tables" do
    get structure_project_path(projects(:gemini))
    assert_response :success

    Relationship.where(project: projects(:gemini)).destroy_all
    projects(:gemini).relationship_types.destroy_all
    projects(:gemini).entities.destroy_all
    projects(:gemini).entity_types.destroy_all

    get structure_project_path(projects(:gemini))

    assert_match(/No entity types yet/, response.body)
    assert_match(/No relationship types yet/, response.body)
  end

  # --- the data side ---------------------------------------------------------

  # A project's data is a card per kind of thing, not one list of everything.
  test "the project page is a card per entity type, with its count" do
    get project_path(@project)

    assert_response :success
    assert_select ".card", @project.entity_types.count
    assert_select ".card", text: /Rocket Engines/
    assert_select ".card", text: /2 entities/
    assert_select ".card", text: /Capsule/, count: 0
  end

  test "the project page has no Entities heading and no unfiltered list" do
    get project_path(@project)

    assert_select "h1", { text: "Entities", count: 0 }
    assert_select "a[href=?]", project_entity_path(@project, entities(:f1)), count: 0
  end

  # The card's own href is followed, so the link and the route are checked
  # against each other rather than separately.
  test "a card opens that type's entities and no other type's" do
    get project_path(@project)
    # Cards name the type in the plural.
    href = css_select(".card a").detect { |a| a.text.strip == "Rocket Engines" }["href"]

    get href

    assert_response :success
    assert_select "h1", "Rocket Engine"
    assert_select "a[href=?]", project_entity_path(@project, entities(:f1))
    assert_select "a[href=?]", project_entity_path(@project, entities(:saturn_v)), count: 0
  end

  test "the typed route is the type's name, hyphenated and pluralised" do
    assert_equal "rocket-engines", entity_types(:rocket_engine).slug

    get project_typed_entities_path(@project, "rocket-engines")

    assert_response :success
    assert_select "h1", "Rocket Engine"
  end

  test "an unknown slug is not found rather than an empty list" do
    get project_typed_entities_path(@project, "no-such-things")

    assert_response :not_found
  end

  test "another project's type does not resolve under this project" do
    get project_typed_entities_path(@project, entity_types(:gemini_capsule).slug)

    assert_response :not_found
  end

  test "a type with no entities of it says so" do
    empty = @project.entity_types.create!(name: "Ground Station")

    get project_typed_entities_path(@project, empty.slug)

    assert_response :success
    assert_match(/No Ground Station entities yet/, response.body)
  end

  test "a project with no entity types says so rather than showing no cards" do
    get project_path(projects(:gemini))

    assert_response :success

    Relationship.where(project: projects(:gemini)).destroy_all
    projects(:gemini).relationship_types.destroy_all
    projects(:gemini).entities.destroy_all
    projects(:gemini).entity_types.destroy_all

    get project_path(projects(:gemini))

    assert_match(/no entity types yet/, response.body)
  end

  # --- the tabs --------------------------------------------------------------

  # The tab strip is gone from the side pages too, so the project listing — one
  # click away in the banner — is the only route between the two sides. That one
  # remaining path is asserted rather than assumed.
  test "neither side renders a tab strip, and both still render their content" do
    get structure_project_path(@project)
    assert_response :success
    assert_select "ul.nav-tabs", count: 0
    assert_select "h1", text: "Entity Types"

    get project_path(@project)
    assert_response :success
    assert_select "ul.nav-tabs", count: 0
    assert_select ".card"
  end

  # The banner carries both: the project name back to the listing, and a gear
  # into the project's structure.
  test "the banner links the listing and the project's structure" do
    get project_path(@project)

    assert_select "nav.navbar a[href=?]", projects_path, text: @project.name
    assert_select "nav.navbar a[href=?]", structure_project_path(@project)
  end

  test "the gear is absent where there is no project yet" do
    get new_project_path

    assert_response :success
    assert_select "nav.navbar svg", count: 0
  end

  # The old index addresses moved; the per-record ones did not.
  # These now match the typed-entities catch-all, so they must fail as unknown
  # slugs rather than as unroutable paths — which is what the reserved-slug
  # validation exists to keep true.
  test "the old index paths do not list anything" do
    %w[entities entity_types relationship_types data].each do |path|
      # Rendering the 404 page drops the test session, so each pass signs in
      # again rather than the second one redirecting to the login page and
      # looking like a pass for the wrong reason.
      sign_in users(:admin)

      get "/projects/#{@project.id}/#{path}"

      assert_response :not_found, "#{path} should not resolve"
    end
  end

  test "the per-record routes still resolve" do
    get project_entity_path(@project, entities(:f1))
    assert_response :success

    get project_entity_type_path(@project, entity_types(:rocket_engine))
    assert_response :success

    get project_relationship_type_path(@project, relationship_types(:powers))
    assert_response :success
  end

  # --- the banner ------------------------------------------------------------

  test "the banner names the project you are in and links back to the listing" do
    get structure_project_path(@project)

    assert_select "nav.navbar" do
      assert_select "a.navbar-brand", text: "Trellis"
      assert_select "a[href=?]", projects_path, text: "Apollo Program"
    end
  end

  test "the banner names the project on a record page too" do
    get project_entity_path(@project, entities(:f1))

    assert_select "nav.navbar a[href=?]", projects_path, text: "Apollo Program"
  end

  test "the banner names no project on the listing or outside a project" do
    get projects_path
    assert_select "nav.navbar a[href=?]", projects_path, count: 0

    get sources_path
    assert_select "nav.navbar a[href=?]", projects_path, count: 0
  end

  # The project moved to the banner, so saying it again in the page is noise.
  test "the in-page breadcrumb is gone" do
    get structure_project_path(@project)

    assert_select "nav[aria-label=?]", "breadcrumb", count: 0
  end

  # --- the attribute popover -------------------------------------------------

  test "an entity type on the ontology page carries its attributes as a popover" do
    get structure_project_path(@project)

    assert_select "a[data-controller=?][data-bs-title=?]", "type-popover", "Rocket Engine" do |links|
      content = links.first["data-bs-content"]

      assert_match(/thrust_kn \(float\)/, content)
      assert_match(/chambers \(int\)/, content)
      assert_match(/first_flight \(datetime\)/, content)
    end
  end

  test "a relationship type carries its attributes as a popover" do
    get structure_project_path(@project)

    assert_select "a[data-controller=?][data-bs-title=?]", "type-popover", "Powers" do |links|
      assert_match(/engine_count \(int\)/, links.first["data-bs-content"])
    end
  end

  # An empty box on hover reads as broken, so it says what it means.
  test "a type with no attributes says so rather than popping up nothing" do
    get structure_project_path(@project)

    assert_select "a[data-controller=?][data-bs-title=?]", "type-popover", "Bare Type" do |links|
      assert_equal "No attributes defined.", links.first["data-bs-content"]
    end
  end

  test "an entity's own page carries the popover on the type it names" do
    get project_entity_path(@project, entities(:f1))

    assert_select "a[data-controller=?][data-bs-title=?]", "type-popover", "Rocket Engine"
  end

  test "a relationship's edit page carries the popover on its type" do
    get edit_project_relationship_path(@project, relationships(:f1_powers_saturn_v))

    assert_select "a[data-controller=?][data-bs-title=?]", "type-popover", "Powers"
  end

  # --- tabs belong only to the two sides -------------------------------------
  #
  # A record page is neither index, so the tabs would render with neither active
  # — a control with no state. Asserted per template, because they are separate
  # files and one of them keeping the tabs is exactly the mistake being fixed.

  ONTOLOGY_RECORD_PAGES = %i[show new edit].freeze

  test "an entity type's pages carry a back link to the ontology and no tabs" do
    [ project_entity_type_path(@project, entity_types(:rocket_engine)),
      new_project_entity_type_path(@project),
      edit_project_entity_type_path(@project, entity_types(:rocket_engine)) ].each do |path|
      get path

      assert_response :success
      assert_select "ul.nav-tabs", { count: 0 }, "#{path} should not carry the side tabs"
      # minimum rather than exactly one: a form also offers Cancel to the
      # same place, which is correct, not a duplicate.
      assert_select "a[href=?]", structure_project_path(@project), { minimum: 1 },
                    "#{path} should link back to the ontology"
    end
  end

  test "a relationship type's pages and an attribute form do the same" do
    [ project_relationship_type_path(@project, relationship_types(:powers)),
      new_project_relationship_type_path(@project),
      edit_project_relationship_type_path(@project, relationship_types(:powers)),
      edit_project_relationship_type_path(@project, relationship_types(:powers)) ].each do |path|
      get path

      assert_response :success
      assert_select "ul.nav-tabs", { count: 0 }, "#{path} should not carry the side tabs"
    end
  end

  test "an entity's pages and a relationship's edit page carry a back link to the data" do
    [ project_entity_path(@project, entities(:f1)),
      new_project_entity_path(@project),
      edit_project_entity_path(@project, entities(:f1)),
      edit_project_relationship_path(@project, relationships(:f1_powers_saturn_v)) ].each do |path|
      get path

      assert_response :success
      assert_select "ul.nav-tabs", { count: 0 }, "#{path} should not carry the side tabs"
      assert_select "a[href=?]", project_path(@project), { minimum: 1 },
                    "#{path} should link back to the data"
    end
  end

  # A rename that misses one site is the whole failure mode, so the old word is
  # asserted absent rather than the new one asserted present.
  test "the product calls this side Structure, not Ontology" do
    get projects_path
    assert_select "a[href=?]", structure_project_path(@project), text: /Structure/
    assert_no_match(/Ontology/, response.body)

    get structure_project_path(@project)
    assert_no_match(/Ontology/, response.body)

    get edit_project_entity_type_path(@project, entity_types(:rocket_engine))
    assert_no_match(/Ontology/, response.body)
    assert_select "a[href=?]", structure_project_path(@project), text: /Structure/
  end

  test "the old ontology path no longer resolves" do
    get "/projects/#{@project.id}/ontology"

    assert_response :not_found
  end

  # --- the project's types in the sidebar ------------------------------------

  test "inside a project the sidebar lists that project's entity types" do
    get project_path(@project)

    assert_select "nav.sidebar" do
      @project.entity_types.each do |type|
        assert_select "a[href=?]", project_typed_entities_path(@project, type.slug), text: type.name
      end
      assert_select "a", text: "Capsule", count: 0
    end
  end

  # Following the sidebar's own href checks the link and the route against each
  # other rather than separately.
  test "a sidebar link lands on that type's list" do
    get project_path(@project)
    href = css_select("nav.sidebar a").detect { |a| a.text.strip == "Rocket Engine" }["href"]

    get href

    assert_response :success
    assert_select "h1", "Rocket Engine"
  end

  test "the section is absent outside a project" do
    get projects_path
    assert_select "nav.sidebar a[href*=?]", "rocket-engines", count: 0

    get sources_path
    assert_select "nav.sidebar a[href*=?]", "rocket-engines", count: 0
  end

  # An empty heading is worse than no heading.
  test "a project with no entity types renders no section for it" do
    Relationship.where(project: projects(:gemini)).destroy_all
    projects(:gemini).relationship_types.destroy_all
    projects(:gemini).entities.destroy_all
    projects(:gemini).entity_types.destroy_all

    get project_path(projects(:gemini))

    assert_select "nav.sidebar h6", text: projects(:gemini).name, count: 0
  end

  # The unsaved record on a "new type" page is already in the association's
  # target and has no address; the sidebar must not try to link it.
  test "the new type form does not put a blank link in the sidebar" do
    get new_project_entity_type_path(@project)

    assert_response :success
    assert_select "nav.sidebar a[href$=?]", "/", count: 0
  end

  test "cards name their type in the plural" do
    get project_path(@project)

    assert_select ".card a", text: "Rocket Engines"
    assert_select ".card a", text: "Launch Vehicles"
    assert_select ".card a", { text: "Rocket Engine", count: 0 }
  end

  # --- columns on a type's list ----------------------------------------------

  test "a type's list shows a column per displayed attribute, in the type's order" do
    get project_typed_entities_path(@project, entity_types(:rocket_engine).slug)

    assert_response :success
    headers = css_select("table th").map { |th| th.text.strip }

    assert_equal [ "Name", "chambers", "first_flight", "manufacturer", "thrust_kn" ], headers
  end

  # Read as a list rather than cell by cell, so a column shift is caught.
  test "a row shows each value in its own column, blank where nothing is recorded" do
    get project_typed_entities_path(@project, entity_types(:rocket_engine).slug)

    row = css_select("tbody tr").detect { |r| r.text.include?("Rocketdyne F-1") }
    cells = row.css("td").map { |td| td.text.strip }

    assert_equal "Rocketdyne F-1", cells[0]
    assert_equal "", cells[1]
    assert_equal "", cells[2]
    assert_equal "Rocketdyne", cells[3]
    assert_equal "6770.0", cells[4]
  end

  test "an undisplayed attribute is not a column" do
    entity_type_attributes(:engine_thrust).update!(is_displayed_on_index: false)

    get project_typed_entities_path(@project, entity_types(:rocket_engine).slug)

    headers = css_select("table th").map { |th| th.text.strip }
    assert_not_includes headers, "thrust_kn"
  end

  test "a disabled attribute is not a column even when flagged for display" do
    entity_type_attributes(:engine_thrust).update!(is_disabled: true, is_displayed_on_index: true)

    get project_typed_entities_path(@project, entity_types(:rocket_engine).slug)

    headers = css_select("table th").map { |th| th.text.strip }
    assert_not_includes headers, "thrust_kn"
  end

  test "a type with no displayed attributes still lists its entities" do
    entity_types(:rocket_engine).entity_type_attributes.update_all(is_displayed_on_index: false)

    get project_typed_entities_path(@project, entity_types(:rocket_engine).slug)

    assert_response :success
    assert_equal [ "Name" ], css_select("table th").map { |th| th.text.strip }
    assert_select "a", text: "Rocketdyne F-1"
  end

  # Attributes are edited on their type's form now, so the checkbox lives there.
  test "the type form carries a display checkbox per attribute" do
    get edit_project_entity_type_path(@project, entity_types(:rocket_engine))

    assert_select "input[type=checkbox][name*=?]", "[is_displayed_on_index]"
  end

  # A card is a way in; the list it opens shows the attributes as columns.
  test "the project page cards carry no attribute popover" do
    get project_path(@project)

    assert_select ".card a[data-controller=?]", "type-popover", count: 0
  end

  # Still present where a type is named rather than opened.
  test "the structure page still carries popovers" do
    get structure_project_path(@project)

    assert_select "a[data-controller=?]", "type-popover"
  end
end
