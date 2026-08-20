require "test_helper"

class EntityTypesControllerTest < ActionDispatch::IntegrationTest
  setup { @project = projects(:apollo) }


  test "show lists the type's attributes and their value types" do
    get project_entity_type_path(@project, entity_types(:rocket_engine))

    assert_response :success
    assert_select "td", text: "thrust_kn"
    assert_select "td", text: "float"
  end


  test "show renders empty states for a type with no attributes and no entities" do
    type = @project.entity_types.create!(name: "Lonely")

    get project_entity_type_path(@project, type)

    assert_response :success
    assert_match(/No attributes defined/, response.body)
    assert_match(/No relationship types connect this entity type/, response.body)
  end

  test "show lists relationship types with this type at either end" do
    get project_entity_type_path(@project, entity_types(:rocket_engine))

    assert_response :success
    # Outgoing, outgoing, and both ends at once. A type is connected by every
    # relationship type that names it, not only the ones it points out of.
    assert_select "a", text: "Powers"
    assert_select "a", text: "Bare Relation"
    assert_select "a", text: "Supersedes"
  end

  test "show lists a relationship type joining a type to itself only once" do
    get project_entity_type_path(@project, entity_types(:rocket_engine))

    # Supersedes is in both halves of the query. Once is the answer; twice is
    # what an implementation that adds outgoing to incoming produces.
    assert_select "a", text: "Supersedes", count: 1
  end

  test "show lists a relationship type that only points at this type" do
    get project_entity_type_path(@project, entity_types(:bare))

    assert_response :success
    # Bare Type is the `to` end of Bare Relation and the `from` end of nothing.
    # A type with no outgoing relationship types is not a type with none.
    assert_select "a", text: "Bare Relation"
  end

  test "show links the other end of a relationship type but not this one" do
    engine = entity_types(:rocket_engine)

    get project_entity_type_path(@project, engine)

    assert_response :success
    assert_select "a[href=?]", project_entity_type_path(@project, entity_types(:launch_vehicle))
    # Linking to the page being viewed is a dead control, and the plain-text end
    # is what shows which side of the relationship this type is on.
    assert_select "a[href=?]", project_entity_type_path(@project, engine), count: 0
  end

  test "show lists only the relationship types that name this type" do
    get project_entity_type_path(@project, entity_types(:launch_vehicle))

    assert_response :success
    # Launch Vehicle is the `to` end of Powers and appears in nothing else. The
    # other two Apollo relationship types are both about Rocket Engine, so a
    # query that lost its where clause would put them here.
    assert_select "a", text: "Powers"
    assert_select "a", text: "Supersedes", count: 0
    assert_select "a", text: "Bare Relation", count: 0
  end

  test "create makes a type" do
    assert_difference -> { EntityType.count }, 1 do
      post project_entity_types_path(@project), params: { entity_type: { name: "Spacecraft", description: "A ship." } }
    end

    assert_redirected_to project_entity_type_path(@project, EntityType.find_by(name: "Spacecraft"))
  end

  test "create rejects a duplicate name and makes nothing" do
    assert_no_difference -> { EntityType.count } do
      post project_entity_types_path(@project), params: { entity_type: { name: "Rocket Engine" } }
    end

    assert_response :unprocessable_entity
  end

  test "update renames a type" do
    type = entity_types(:launch_vehicle)

    patch project_entity_type_path(@project, type), params: { entity_type: { name: "Launcher" } }

    assert_redirected_to project_entity_type_path(@project, type)
    assert_equal "Launcher", type.reload.name
  end

  test "update rejects a blank name" do
    type = entity_types(:launch_vehicle)

    patch project_entity_type_path(@project, type), params: { entity_type: { name: "" } }

    assert_response :unprocessable_entity
    assert_equal "Launch Vehicle", type.reload.name
  end

  test "destroy removes a type nothing is an instance of" do
    type = @project.entity_types.create!(name: "Disposable")

    assert_difference -> { EntityType.count }, -1 do
      delete project_entity_type_path(@project, type)
    end

    assert_redirected_to structure_project_path(@project)
  end

  # A type with instances is not something to cascade away on a button press.
  test "destroy refuses a type that still has entities and says why" do
    type = entity_types(:rocket_engine)

    assert_no_difference -> { EntityType.count } do
      delete project_entity_type_path(@project, type)
    end

    assert_redirected_to project_entity_type_path(@project, type)
    assert flash[:alert].present?
  end

  # --- scoping ---------------------------------------------------------------


  test "another project's entity type is not found under this project" do
    get project_entity_type_path(@project, entity_types(:gemini_capsule))

    assert_response :not_found
  end

  test "create assigns the project from the url" do
    post project_entity_types_path(@project), params: { entity_type: { name: "Spacecraft" } }

    assert_equal @project, EntityType.find_by(name: "Spacecraft").project
  end

  # The uniqueness of a type name is per project: two projects describing a
  # "Capsule" each is the normal case, not a collision.
  test "a name used in another project is free in this one" do
    assert_difference -> { EntityType.count }, 1 do
      post project_entity_types_path(@project), params: { entity_type: { name: "Capsule" } }
    end
  end

  # The description is prompt context, not a tidy-up note, and someone typing one
  # needs to know that while they type it. Asserted on both actions rather than
  # one: the shared partial is what makes them agree, and a test on `new` alone
  # would not notice `edit` losing it.
  test "the form says the description is the extraction context" do
    get new_project_entity_type_path(@project)
    assert_match(/context for extracting entities of this type from source material/, response.body)

    get edit_project_entity_type_path(@project, entity_types(:rocket_engine))
    assert_match(/context for extracting entities of this type from source material/, response.body)
  end

  # The type's page says what the type is; what exists of it belongs on the list
  # built for that, which is paginated and reached from the card and sidebar.
  test "show renders no entity list" do
    get project_entity_type_path(@project, entity_types(:rocket_engine))

    assert_response :success
    assert_select "h2", { text: "Entities", count: 0 }
    assert_select "a[href=?]", project_entity_path(@project, entities(:f1)), count: 0
  end

  test "show still renders the type itself" do
    get project_entity_type_path(@project, entity_types(:rocket_engine))

    assert_select "h1", "Rocket Engine"
    assert_select "td", text: "thrust_kn"
  end

  test "the type's entities are still reachable at their own address" do
    get project_typed_entities_path(@project, entity_types(:rocket_engine).slug)

    assert_response :success
    assert_select "a[href=?]", project_entity_path(@project, entities(:f1))
  end
end
