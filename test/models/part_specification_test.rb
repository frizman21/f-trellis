require "test_helper"

# PartTypeParameter (what a type is measured by) and PartDetailParameter (one
# measured value).
class PartSpecificationTest < ActiveSupport::TestCase
  setup do
    @physical = PartType.create!(name: "Physical Part #{SecureRandom.hex(3)}")
    @weight = @physical.part_type_parameters.create!(name: "weight", unit: "g")
    @material = @physical.part_type_parameters.create!(name: "material", value_type: "text")

    @report = SourceProcessingReport.create!(source: sources(:one),
                                             skill_revision: skill_revisions(:promoted_1),
                                             status: "processing")
    @part = Part.create!
    @detail = PartDetail.create!(part: @part, source_processing_report: @report, name: "Widget",
                                 as_of: Time.current, confidence_tenths: 900)
    @detail.part_types = [ @physical ]
  end

  # 12 what? A number with no unit is not a measurement, and the whole point of
  # promoting these out of the property bag was to carry the unit.
  test "a numeric parameter must declare a unit" do
    parameter = @physical.part_type_parameters.build(name: "length")

    assert_not parameter.valid?
    assert_includes parameter.errors.attribute_names, :unit
  end

  test "a text parameter needs no unit" do
    assert @physical.part_type_parameters.build(name: "finish", value_type: "text").valid?
  end

  test "parameter names are normalised into keys" do
    parameter = @physical.part_type_parameters.create!(name: "  Max Power Draw ", unit: "W")

    assert_equal "max_power_draw", parameter.name
  end

  test "one part type cannot declare the same parameter twice" do
    duplicate = @physical.part_type_parameters.build(name: "WEIGHT", unit: "kg")

    assert_not duplicate.valid?
    assert_includes duplicate.errors.attribute_names, :name
  end

  test "two part types can each declare a parameter of the same name" do
    other = PartType.create!(name: "Other #{SecureRandom.hex(3)}")

    assert other.part_type_parameters.build(name: "weight", unit: "lb").valid?
  end

  test "a numeric value lands in value_number and reads back with its unit" do
    spec = @detail.part_detail_parameters.create!(part_type_parameter: @weight, value_number: 1375)

    assert_equal "1375 g", spec.to_s
    assert_equal 1375, spec.value
  end

  test "trailing zeros are not shown" do
    spec = @detail.part_detail_parameters.create!(part_type_parameter: @weight, value_number: 1.5)

    assert_equal "1.5 g", spec.to_s
  end

  test "a text value lands in value_text" do
    spec = @detail.part_detail_parameters.create!(part_type_parameter: @material,
                                                  value_text: "carbon fibre")

    assert_equal "carbon fibre", spec.to_s
  end

  test "a numeric parameter refuses a row with no number" do
    spec = @detail.part_detail_parameters.build(part_type_parameter: @weight, value_text: "heavy")

    assert_not spec.valid?
    assert_includes spec.errors.attribute_names, :value_number
  end

  test "a text parameter refuses a row with no text" do
    spec = @detail.part_detail_parameters.build(part_type_parameter: @material, value_number: 5)

    assert_not spec.valid?
    assert_includes spec.errors.attribute_names, :value_text
  end

  test "one detail states a parameter once" do
    @detail.part_detail_parameters.create!(part_type_parameter: @weight, value_number: 1)
    duplicate = @detail.part_detail_parameters.build(part_type_parameter: @weight, value_number: 2)

    assert_not duplicate.valid?
  end

  # A conversion is where an extraction goes wrong quietly, so the page's own
  # words are kept — and only flagged where they actually differ.
  test "a value is marked converted only when the page said it differently" do
    converted = @detail.part_detail_parameters.create!(part_type_parameter: @weight,
                                                       value_number: 624, as_stated: "1.375 lb")
    verbatim = @detail.part_detail_parameters.create!(part_type_parameter: @material,
                                                      value_text: "carbon fibre",
                                                      as_stated: "carbon fibre")

    assert converted.converted?
    assert_not verbatim.converted?
  end

  # A part carries several types, and that is the whole inheritance mechanism —
  # a drone that is a Physical Part and a Battery is measured by both sets.
  test "a detail is measured by every parameter its types declare" do
    battery = PartType.create!(name: "Battery #{SecureRandom.hex(3)}")
    capacity = battery.part_type_parameters.create!(name: "capacity", unit: "mAh")
    @detail.part_types = [ @physical, battery ]

    assert_equal [ capacity, @material, @weight ].map(&:id).sort,
                 @detail.available_parameters.map(&:id).sort
  end

  test "dropping a part type parameter drops the values recorded against it" do
    @detail.part_detail_parameters.create!(part_type_parameter: @weight, value_number: 1)

    assert_difference "PartDetailParameter.count", -1 do
      @weight.destroy!
    end
  end
end
