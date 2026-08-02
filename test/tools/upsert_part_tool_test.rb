require "test_helper"

class UpsertPartToolTest < ActiveSupport::TestCase
  setup do
    PartType.destroy_all

    @physical = PartType.create!(name: "Physical Part")
    @physical.part_type_parameters.create!(name: "weight", unit: "g")
    @physical.part_type_parameters.create!(name: "material", value_type: "text")

    @battery = PartType.create!(name: "Battery")
    @battery.part_type_parameters.create!(name: "capacity", unit: "mAh")

    @report = SourceProcessingReport.create!(source: sources(:one),
                                             skill_revision: skill_revisions(:promoted_1),
                                             status: "processing")
    @tool = UpsertPartTool.new(@report)
  end

  def upsert(*entries) = @tool.execute(parts: entries)[:results]

  def spec(parameter, value, **extra)
    { parameter: parameter, value: value }.merge(extra)
  end

  test "records a whole batch in one call" do
    assert_difference [ "Part.count", "PartDetail.count" ], 2 do
      results = upsert({ name: "Widget A", part_types: [ "Physical Part" ] },
                       { name: "Widget B", part_types: [ "Physical Part" ] })

      assert_equal 2, results.size
      assert results.all? { |r| r[:created] }
    end
  end

  test "records the specifications the part's types declare" do
    results = upsert(name: "Drone One", part_types: [ "Physical Part", "Battery" ],
                     specifications: [ spec("weight", "624", as_stated: "1.375 lb"),
                                       spec("capacity", "5,000"),
                                       spec("material", "carbon fibre") ])

    assert_equal 3, results.first[:specifications_recorded]
    assert_empty results.first[:specification_errors]

    detail = PartDetail.find(results.first[:detail_id])
    assert_equal [ "5000 mAh", "carbon fibre", "624 g" ], detail.part_detail_parameters.map(&:to_s)
    assert_equal "1.375 lb", detail.part_detail_parameters.find { |p| p.name == "weight" }.as_stated
  end

  # A column of weights in mixed units compares nothing, so the tool refuses
  # rather than storing a number that means something else.
  test "a value in the wrong unit is refused, with the conversion asked for" do
    results = upsert(name: "Drone One", part_types: [ "Physical Part" ],
                     specifications: [ spec("weight", "1.375", unit: "lb") ])

    assert_equal 0, results.first[:specifications_recorded]
    assert_match(/given in lb, but is recorded in g — convert it/, results.first[:specification_errors].first)
    assert_empty PartDetail.find(results.first[:detail_id]).part_detail_parameters
  end

  test "the declared unit is assumed when the model does not restate it" do
    results = upsert(name: "Drone One", part_types: [ "Physical Part" ],
                     specifications: [ spec("weight", "624") ])

    assert_equal 1, results.first[:specifications_recorded]
  end

  # Inventing a parameter would make the taxonomy meaningless; the property bag
  # is where an undeclared fact belongs.
  test "a parameter no type declares is refused and named" do
    results = upsert(name: "Drone One", part_types: [ "Physical Part" ],
                     specifications: [ spec("capacity", "5000") ])

    assert_equal 0, results.first[:specifications_recorded]
    assert_match(/'capacity' is not a parameter of Physical Part/, results.first[:specification_errors].first)
  end

  test "one bad specification does not cost the others" do
    results = upsert(name: "Drone One", part_types: [ "Physical Part" ],
                     specifications: [ spec("weight", "624"), spec("nonsense", "1"),
                                       spec("material", "aluminium") ])

    assert_equal 2, results.first[:specifications_recorded]
    assert_equal 1, results.first[:specification_errors].size
  end

  test "a numeric parameter given prose is refused rather than stored as zero" do
    results = upsert(name: "Drone One", part_types: [ "Physical Part" ],
                     specifications: [ spec("weight", "light") ])

    assert_match(/needs a number/, results.first[:specification_errors].first)
  end

  test "a part naming no configured type is refused, with the valid ones listed" do
    assert_no_difference "Part.count" do
      results = upsert(name: "Drone One", part_types: [ "Spaceship" ])

      assert_match(/no part type matched Spaceship/, results.first[:error])
      assert_match(/valid types are Battery and Physical Part/, results.first[:error])
    end
  end

  # A type the taxonomy does not have is a claim it cannot hold — recorded
  # against the ones it can, and reported rather than silently dropped.
  test "an unknown type alongside a known one is reported, not fatal" do
    results = upsert(name: "Drone One", part_types: [ "Physical Part", "Spaceship" ])

    assert results.first[:part_id].present?
    assert_includes results.first[:specification_errors], "part type 'Spaceship' is not configured"
    assert_equal [ "Physical Part" ], PartDetail.find(results.first[:detail_id]).part_types.map(&:name)
  end

  test "a name that already exists gets a new detail on the same part" do
    first = upsert(name: "Drone One", part_types: [ "Physical Part" ]).first

    assert_difference "PartDetail.count", 1 do
      assert_no_difference "Part.count" do
        second = upsert(name: "DRONE ONE", part_types: [ "Physical Part" ]).first

        assert_equal first[:part_id], second[:part_id]
        assert_not second[:created]
      end
    end
  end

  test "the newest detail becomes the part's current one" do
    results = upsert(name: "Drone One", part_types: [ "Physical Part" ])

    part = Part.find(results.first[:part_id])
    assert_equal results.first[:detail_id], part.current_detail_id
  end

  test "an entry with no name is refused and the rest of the batch is kept" do
    results = upsert({ name: "  ", part_types: [ "Physical Part" ] },
                     { name: "Widget B", part_types: [ "Physical Part" ] })

    assert_equal "name is required", results[0][:error]
    assert results[1][:part_id].present?
  end

  test "an empty batch is refused" do
    assert_equal({ error: "parts must be a non-empty array" }, @tool.execute(parts: []))
  end

  test "attributes that are not parameters land in the property bag" do
    results = upsert(name: "Drone One", part_types: [ "Physical Part" ],
                     additional_attributes: [ { key: "manufacturer_part_number", value: "DR-1" } ])

    assert_equal({ "manufacturer_part_number" => "DR-1" },
                 PartDetail.find(results.first[:detail_id]).additional_attributes)
  end

  # The taxonomy is the useful half of the description: a model told a Battery
  # has capacity in mAh answers 5000, and one told nothing answers "5 Ah".
  test "the tool description lists every part type and what it is measured by" do
    description = @tool.description

    assert_match(/Battery: capacity \(mAh\)/, description)
    assert_match(/Physical Part: material \(text\), weight \(g\)/, description)
  end
end
