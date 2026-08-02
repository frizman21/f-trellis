require "test_helper"

class PartsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @physical = PartType.create!(name: "Physical Part #{SecureRandom.hex(3)}")
    @weight = @physical.part_type_parameters.create!(name: "weight", unit: "g")
    @material = @physical.part_type_parameters.create!(name: "material", value_type: "text")

    report = SourceProcessingReport.create!(source: sources(:one),
                                            skill_revision: skill_revisions(:promoted_1),
                                            status: "processing")
    @part = Part.create!
    @detail = PartDetail.create!(part: @part, source_processing_report: report, name: "Drone One",
                                 as_of: Time.current, confidence_tenths: 900)
    @detail.part_types = [ @physical ]
    @part.update!(current_detail: @detail)
  end

  test "the part page shows each specification in the unit its parameter declares" do
    @detail.part_detail_parameters.create!(part_type_parameter: @weight, value_number: 624,
                                           confidence_tenths: 950)

    get part_path(@part)

    assert_response :success
    assert_match "Specifications", @response.body
    assert_select "td", text: "624 g"
    assert_select "td", text: "95.0%"
  end

  # A conversion is where an extraction goes wrong quietly, so the page's own
  # words sit beside the stored value — but only where they differ.
  test "the page's own wording is shown only where it differs from the stored value" do
    @detail.part_detail_parameters.create!(part_type_parameter: @weight, value_number: 624,
                                           as_stated: "1.375 lb")
    @detail.part_detail_parameters.create!(part_type_parameter: @material, value_text: "carbon fibre",
                                           as_stated: "carbon fibre")

    get part_path(@part)

    assert_response :success
    assert_select "td", text: "1.375 lb"
    assert_select "td", text: "carbon fibre", count: 1, message: "the verbatim value must not be repeated"
  end

  test "a part with nothing measured says what its types would measure" do
    get part_path(@part)

    assert_response :success
    assert_match "Nothing measured yet", @response.body
    assert_match "material, weight (g)", @response.body
  end

  test "a part whose types measure nothing points at the part types page" do
    @detail.part_types = [ PartType.create!(name: "Unmeasured #{SecureRandom.hex(3)}") ]

    get part_path(@part)

    assert_response :success
    assert_match "Its types declare no parameters", @response.body
  end
end
