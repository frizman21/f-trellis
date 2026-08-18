require "test_helper"

# The five new type taxonomies all run the same controller shape, so this
# covers one tier 1 type (ScienceType) and one relationship type
# (ScienceTechnologyType) rather than repeating itself five times.
class ScienceTechnologyTypesControllerTest < ActionDispatch::IntegrationTest
  test "the science type index lists a type with its attribute keys" do
    type = ScienceType.create!(name: "Discipline #{SecureRandom.hex(3)}",
                               description: "A named field of study.",
                               additional_attribute_keys: [ "parent_field" ])

    get science_types_path

    assert_response :success
    assert_match type.name, @response.body
    assert_match "A named field of study.", @response.body
    assert_match "parent_field", @response.body
  end

  test "creating a science type splits comma-separated attribute keys into an array" do
    name = "Principle #{SecureRandom.hex(3)}"

    post science_types_path, params: {
      science_type: { name: name, description: "A law a field rests on.",
                      additional_attribute_keys: "named_after, first_stated " }
    }

    assert_redirected_to science_types_path
    assert_equal %w[named_after first_stated], ScienceType.find_by(name: name).additional_attribute_keys
  end

  test "creating a technology type works the same way" do
    name = "Method #{SecureRandom.hex(3)}"

    post technology_types_path, params: {
      technology_type: { name: name, description: "A way of doing something.",
                         additional_attribute_keys: "maturity" }
    }

    assert_redirected_to technology_types_path
    assert_equal %w[maturity], TechnologyType.find_by(name: name).additional_attribute_keys
  end

  test "a relationship type index has a link to its new form" do
    get science_technology_types_path

    assert_response :success
    assert_match new_science_technology_type_path, @response.body
  end

  test "creating a relationship type splits its attribute keys" do
    name = "Application #{SecureRandom.hex(3)}"

    post science_technology_types_path, params: {
      science_technology_type: { name: name, description: "The technology applies the science.",
                                 additional_attribute_keys: "since, maturity" }
    }

    assert_redirected_to science_technology_types_path
    assert_equal %w[since maturity],
                 ScienceTechnologyType.find_by(name: name).additional_attribute_keys
  end

  test "updating a relationship type rewrites its keys, and a blank field clears them" do
    type = PartTechnologyType.create!(name: "Dependency #{SecureRandom.hex(3)}",
                                      additional_attribute_keys: [ "subsystem" ])

    patch part_technology_type_path(type), params: {
      part_technology_type: { name: type.name, additional_attribute_keys: "" }
    }

    assert_redirected_to part_technology_types_path
    assert_equal [], type.reload.additional_attribute_keys
  end

  # The unique index on `name` is in the schema; without a matching validation
  # a duplicate would reach the database and 500 rather than re-render the form.
  test "a duplicate name is refused rather than raised" do
    existing = PersonScienceType.create!(name: "Researcher #{SecureRandom.hex(3)}")

    assert_no_difference "PersonScienceType.count" do
      post person_science_types_path, params: { person_science_type: { name: existing.name } }
    end

    assert_response :unprocessable_entity
    assert_match "Name has already been taken", @response.body
  end
end
