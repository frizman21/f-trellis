require "test_helper"

# The two sides of a project, at the addresses named after them.
class ProjectSidesTest < ActionDispatch::IntegrationTest
  setup { @project = projects(:apollo) }

  # --- the ontology side -----------------------------------------------------

  test "ontology lists every entity type and every relationship type at once" do
    get ontology_project_path(@project)

    assert_response :success
    assert_select "h1", text: "Entity Types"
    assert_select "h1", text: "Relationship Types"
    assert_select "a", text: "Rocket Engine"
    assert_select "a", text: "Powers"
  end

  test "ontology shows only this project's types" do
    get ontology_project_path(@project)

    assert_select "a", text: "Capsule", count: 0
    assert_select "a", text: "Docks With", count: 0
  end

  # From and To are two facts about a type, so they are two columns.
  test "the relationship type table has From and To columns carrying the end names" do
    get ontology_project_path(@project)

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
    get ontology_project_path(projects(:gemini))
    assert_response :success

    Relationship.where(project: projects(:gemini)).destroy_all
    projects(:gemini).relationship_types.destroy_all
    projects(:gemini).entities.destroy_all
    projects(:gemini).entity_types.destroy_all

    get ontology_project_path(projects(:gemini))

    assert_match(/No entity types yet/, response.body)
    assert_match(/No relationship types yet/, response.body)
  end

  # --- the data side ---------------------------------------------------------

  test "data lists this project's entities" do
    get data_project_path(@project)

    assert_response :success
    assert_select "a", text: "Rocketdyne F-1"
    assert_select "a", text: "Capsule", count: 0
  end

  test "data shows the empty state when there are no entities" do
    RelationshipTypeValue.delete_all
    Relationship.delete_all
    EntityAttributeValue.delete_all
    Entity.delete_all

    get data_project_path(@project)

    assert_response :success
    assert_match(/No entities yet/, response.body)
  end

  # --- the tabs --------------------------------------------------------------

  test "both sides offer both tabs, with the current one active" do
    get ontology_project_path(@project)
    assert_select "a.nav-link.active[href=?]", ontology_project_path(@project)
    assert_select "a.nav-link[href=?]", data_project_path(@project)

    get data_project_path(@project)
    assert_select "a.nav-link.active[href=?]", data_project_path(@project)
    assert_select "a.nav-link[href=?]", ontology_project_path(@project)
  end

  # The old index addresses moved; the per-record ones did not.
  test "the old index routes no longer resolve" do
    get "/projects/#{@project.id}/entities"
    assert_response :not_found

    get "/projects/#{@project.id}/entity_types"
    assert_response :not_found

    get "/projects/#{@project.id}/relationship_types"
    assert_response :not_found
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
    get ontology_project_path(@project)

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
    get ontology_project_path(@project)

    assert_select "nav[aria-label=?]", "breadcrumb", count: 0
  end

  # --- the attribute popover -------------------------------------------------

  test "an entity type on the ontology page carries its attributes as a popover" do
    get ontology_project_path(@project)

    assert_select "a[data-controller=?][data-bs-title=?]", "type-popover", "Rocket Engine" do |links|
      content = links.first["data-bs-content"]

      assert_match(/thrust_kn \(float\)/, content)
      assert_match(/chambers \(int\)/, content)
      assert_match(/first_flight \(datetime\)/, content)
    end
  end

  test "a relationship type carries its attributes as a popover" do
    get ontology_project_path(@project)

    assert_select "a[data-controller=?][data-bs-title=?]", "type-popover", "Powers" do |links|
      assert_match(/engine_count \(int\)/, links.first["data-bs-content"])
    end
  end

  # An empty box on hover reads as broken, so it says what it means.
  test "a type with no attributes says so rather than popping up nothing" do
    get ontology_project_path(@project)

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
      assert_select "a[href=?]", ontology_project_path(@project), { minimum: 1 },
                    "#{path} should link back to the ontology"
    end
  end

  test "a relationship type's pages and an attribute form do the same" do
    [ project_relationship_type_path(@project, relationship_types(:powers)),
      new_project_relationship_type_path(@project),
      edit_project_relationship_type_path(@project, relationship_types(:powers)),
      new_project_relationship_type_relationship_type_attribute_path(@project, relationship_types(:powers)) ].each do |path|
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
      assert_select "a[href=?]", data_project_path(@project), { minimum: 1 },
                    "#{path} should link back to the data"
    end
  end

  test "the two side pages keep their tabs" do
    [ ontology_project_path(@project), data_project_path(@project) ].each do |path|
      get path

      assert_select "ul.nav-tabs a.nav-link", 2
    end
  end
end
