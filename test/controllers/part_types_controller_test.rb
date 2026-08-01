require "test_helper"

class PartTypesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @part_type = PartType.create!(name: "Battery #{SecureRandom.hex(3)}",
                                  additional_attribute_keys: [ "manufacturer_part_number" ])
    @capacity = @part_type.part_type_parameters.create!(name: "capacity", unit: "mAh")
  end

  test "index says what each type is measured by" do
    get part_types_path

    assert_response :success
    assert_match "capacity (mAh)", @response.body
  end

  test "index says so plainly when a type measures nothing" do
    PartType.create!(name: "Unmeasured #{SecureRandom.hex(3)}")

    get part_types_path

    assert_response :success
    assert_match "Nothing measured", @response.body
  end

  test "the form offers a parameter row" do
    get new_part_type_path

    assert_response :success
    assert_select "input[name=?]", "part_type[part_type_parameters_attributes][0][name]"
    assert_select "select[name=?]", "part_type[part_type_parameters_attributes][0][value_type]"
  end

  test "creating a type creates its parameters" do
    assert_difference "PartTypeParameter.count", 2 do
      post part_types_path, params: {
        part_type: {
          name: "Motor #{SecureRandom.hex(3)}", description: "Spins.",
          additional_attribute_keys: "manufacturer_part_number",
          part_type_parameters_attributes: {
            "0" => { name: "kv_rating", unit: "rpm/V", value_type: "number" },
            "1" => { name: "Winding Style", unit: "", value_type: "text" }
          }
        }
      }
    end

    assert_redirected_to part_types_path
    assert_equal %w[kv_rating winding_style], PartTypeParameter.order(:id).last(2).map(&:name)
  end

  # The form always renders a spare row; submitting it untouched must not create
  # a nameless parameter.
  test "a blank parameter row is ignored" do
    assert_no_difference "PartTypeParameter.count" do
      post part_types_path, params: {
        part_type: { name: "Frame #{SecureRandom.hex(3)}", additional_attribute_keys: "",
                     part_type_parameters_attributes: { "0" => { name: "", unit: "", value_type: "number" } } }
      }
    end
  end

  test "a numeric parameter without a unit is refused rather than saved unitless" do
    assert_no_difference "PartType.count" do
      post part_types_path, params: {
        part_type: { name: "Frame #{SecureRandom.hex(3)}", additional_attribute_keys: "",
                     part_type_parameters_attributes: { "0" => { name: "span", unit: "", value_type: "number" } } }
      }
    end

    assert_response :unprocessable_entity
    assert_match "Part type parameters unit can&#39;t be blank", @response.body
  end

  test "editing a type can add a parameter and drop another" do
    patch part_type_path(@part_type), params: {
      part_type: {
        name: @part_type.name, additional_attribute_keys: "",
        part_type_parameters_attributes: {
          "0" => { id: @capacity.id, name: @capacity.name, unit: "mAh",
                   value_type: "number", _destroy: "1" },
          "1" => { name: "energy", unit: "Wh", value_type: "number" }
        }
      }
    }

    assert_redirected_to part_types_path
    assert_equal [ "energy" ], @part_type.reload.part_type_parameters.map(&:name)
  end
end
