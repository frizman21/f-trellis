require "test_helper"

# A string attribute holding a web address is a link, on the list and on the
# entity's own page. Read off the value: the ontology has no URL type.
class EntityValueLinksTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:apollo)
    @type = entity_types(:rocket_engine)
    @attribute = @type.entity_type_attributes.find_by!(name: "manufacturer")
  end

  def engine_with(manufacturer)
    entity = @project.entities.create!(entity_type: @type, name: "F-1")
    record = entity.entity_attribute_values.build(entity_type_attribute: @attribute)
    record.value = manufacturer
    record.save!
    entity
  end

  test "the list links a value that is a web address" do
    engine_with("https://rocketdyne.example/f-1")

    get project_typed_entities_path(@project, @type.slug)

    assert_response :success
    assert_select "tbody a[href=?][target=?]", "https://rocketdyne.example/f-1", "_blank"
  end

  test "the list leaves a value that is not an address as text" do
    engine_with("Rocketdyne")

    get project_typed_entities_path(@project, @type.slug)

    assert_match(/Rocketdyne/, response.body)
    assert_select "tbody a[href=?]", "Rocketdyne", count: 0
  end

  test "the entity's own page links it too" do
    entity = engine_with("https://rocketdyne.example/f-1")

    get project_entity_path(@project, entity)

    assert_response :success
    assert_select "a[href=?][target=?]", "https://rocketdyne.example/f-1", "_blank"
  end

  # The same value as a link on one page and as text on the other would read as
  # a bug rather than as a decision.
  test "the entity's own page leaves prose as text" do
    entity = engine_with("Rocketdyne")

    get project_entity_path(@project, entity)

    assert_select "a[href=?]", "Rocketdyne", count: 0
  end
end
