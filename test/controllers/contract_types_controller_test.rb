require "test_helper"

# The six new taxonomies all run the same controller shape, so this covers the
# tier 1 type and two of the relationship types rather than repeating itself.
class ContractTypesControllerTest < ActionDispatch::IntegrationTest
  test "the index lists a type with its description and attribute keys" do
    type = ContractType.create!(name: "Grant #{SecureRandom.hex(3)}",
                                description: "Funds work without procuring a deliverable.",
                                additional_attribute_keys: [ "program" ])

    get contract_types_path

    assert_response :success
    assert_match type.name, @response.body
    assert_match "Funds work without procuring a deliverable.", @response.body
    assert_match "program", @response.body
  end

  test "creating a contract type splits comma-separated attribute keys into an array" do
    name = "Development Contract #{SecureRandom.hex(3)}"

    post contract_types_path, params: {
      contract_type: { name: name, description: "Funds building a thing.",
                       additional_attribute_keys: "vehicle, competition " }
    }

    assert_redirected_to contract_types_path
    assert_equal %w[vehicle competition], ContractType.find_by(name: name).additional_attribute_keys
  end

  test "creating a relationship type works the same way" do
    name = "Awardee #{SecureRandom.hex(3)}"

    post contract_organization_types_path, params: {
      contract_organization_type: { name: name, description: "The contract is with them.",
                                    additional_attribute_keys: "role" }
    }

    assert_redirected_to contract_organization_types_path
    assert_equal %w[role], ContractOrganizationType.find_by(name: name).additional_attribute_keys
  end

  test "updating rewrites the keys, and a blank field clears them" do
    type = OrganizationTechnologyType.create!(name: "Licensee #{SecureRandom.hex(3)}",
                                              additional_attribute_keys: [ "licensor" ])

    patch organization_technology_type_path(type), params: {
      organization_technology_type: { name: type.name, additional_attribute_keys: "" }
    }

    assert_redirected_to organization_technology_types_path
    assert_equal [], type.reload.additional_attribute_keys
  end

  test "every new type index renders and offers its new form" do
    [ [ contract_types_path, new_contract_type_path ],
      [ contract_organization_types_path, new_contract_organization_type_path ],
      [ contract_person_types_path, new_contract_person_type_path ],
      [ contract_technology_types_path, new_contract_technology_type_path ],
      [ contract_part_types_path, new_contract_part_type_path ],
      [ organization_technology_types_path, new_organization_technology_type_path ] ].each do |index, form|
      get index

      assert_response :success, "#{index} did not render"
      assert_match form, @response.body, "#{index} has no link to its new form"
    end
  end

  test "a duplicate name is refused rather than raised" do
    existing = ContractTechnologyType.create!(name: "Develop #{SecureRandom.hex(3)}")

    assert_no_difference "ContractTechnologyType.count" do
      post contract_technology_types_path, params: { contract_technology_type: { name: existing.name } }
    end

    assert_response :unprocessable_entity
    assert_match "Name has already been taken", @response.body
  end
end
