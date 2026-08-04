require "test_helper"
require "ruby_llm/schema"

# The params DSL is only evaluated when a request is built, so a malformed
# schema raises at call time against a live provider rather than in the tools'
# own tests. These assertions compile each tool's schema up front.
class ToolSchemaTest < ActiveSupport::TestCase
  BATCHED_TOOLS = {
    UpsertOrganizationTool => "organizations",
    UpsertPersonTool => "people",
    UpsertPartTool => "parts"
  }.freeze

  def schema_for(klass)
    RubyLLM::Schema.create(&klass.params_schema_definition.instance_variable_get(:@block))
  end

  BATCHED_TOOLS.each do |klass, root|
    test "#{klass} compiles to a valid schema" do
      assert_nothing_raised { schema_for(klass) }
    end

    test "#{klass} takes an array of objects at #{root}" do
      property = schema_for(klass).properties[root.to_sym] || schema_for(klass).properties[root]

      assert_equal "array", property[:type], "expected #{root} to be an array"
      assert_equal "object", property[:items][:type]
      assert property[:items][:properties].any?, "expected the entry object to declare properties"
    end

    test "#{klass} declares additional_attributes as key/value pairs the model can fill" do
      entry = (schema_for(klass).properties[root.to_sym] || schema_for(klass).properties[root])[:items]
      attrs = entry[:properties][:additional_attributes]

      assert_equal "array", attrs[:type],
        "a bare object compiles to additionalProperties:false with no properties, " \
        "which the model cannot put anything into"
      assert_equal %i[key value].sort, attrs[:items][:properties].keys.map(&:to_sym).sort
    end
  end

  test "UpsertOrganizationTool requires a name per entry" do
    entry = schema_for(UpsertOrganizationTool).properties[:organizations][:items]

    assert_includes entry[:required].map(&:to_s), "name"
    assert_not_includes entry[:required].map(&:to_s), "acronym"
  end

  test "UpsertPersonTool requires both name parts per entry" do
    entry = schema_for(UpsertPersonTool).properties[:people][:items]

    assert_includes entry[:required].map(&:to_s), "first_name"
    assert_includes entry[:required].map(&:to_s), "last_name"
  end

  test "UpsertPartTool requires a name and at least one type per entry" do
    entry = schema_for(UpsertPartTool).properties[:parts][:items]

    assert_includes entry[:required].map(&:to_s), "name"
    assert_includes entry[:required].map(&:to_s), "part_types"
    assert_not_includes entry[:required].map(&:to_s), "specifications"
  end

  # A specification is three things — which parameter, what value, in what unit —
  # and a schema that dropped any of them would leave the tool guessing.
  test "UpsertPartTool declares specifications as parameter/value objects" do
    specs = schema_for(UpsertPartTool).properties[:parts][:items][:properties][:specifications]

    assert_equal "array", specs[:type]
    assert_equal %i[as_stated parameter unit value],
                 specs[:items][:properties].keys.map(&:to_sym).sort
    assert_equal %w[parameter value], specs[:items][:required].map(&:to_s).sort
  end

  TYPE_TOOLS = {
    CreatePersonOrganizationTypeTool => "person_organization_type_id",
    CreatePersonPersonTypeTool => "person_person_type_id"
  }.freeze

  TYPE_TOOLS.each_key do |klass|
    test "#{klass} compiles to a valid schema" do
      assert_nothing_raised { schema_for(klass) }
    end

    test "#{klass} requires a name and a description, and takes plain string attribute keys" do
      schema = schema_for(klass)

      assert_equal %w[description name], schema.required_properties.map(&:to_s).sort
      assert_equal "array", schema.properties[:additional_attribute_keys][:type]
      assert_equal "string", schema.properties[:additional_attribute_keys][:items][:type]
    end
  end

  # The link tools declare parameters one at a time rather than through a schema
  # block, so there is no block to compile — the equivalent check is that the
  # declared parameters are the ones the tool reads, with the right types and
  # the right ones optional.
  LINK_PARAMS = %i[as_of additional_attributes confidence_tenths].freeze

  [ LinkPartOrganizationTool, RecordingLinkPartOrganizationTool ].each do |klass|
    test "#{klass} declares the part-to-organization parameters" do
      params = klass.parameters

      assert_equal %i[additional_attributes as_of confidence_tenths organization_id part_id type].sort,
                   params.keys.sort
      assert_equal "integer", params[:part_id].type.to_s
      assert_equal "integer", params[:organization_id].type.to_s
      assert_equal "string", params[:type].type.to_s
    end

    test "#{klass} requires the pair and the type, and nothing else" do
      params = klass.parameters

      assert_equal %i[organization_id part_id type], params.select { |_, p| p.required }.keys.sort
      LINK_PARAMS.each { |name| assert_not params[name].required, "#{name} should be optional" }
    end
  end

  # The stand-in an evaluation runs has to be indistinguishable from the writing
  # tool, or the evaluation stops measuring what it claims to.
  test "the recording part link presents the same contract as the writing one" do
    written = LinkPartOrganizationTool.parameters
    recorded = RecordingLinkPartOrganizationTool.parameters

    assert_equal written.keys.sort, recorded.keys.sort
    written.each do |name, param|
      assert_equal param.type, recorded[name].type, "#{name} type differs"
      assert_equal param.required, recorded[name].required, "#{name} requiredness differs"
      assert_equal param.description, recorded[name].description, "#{name} description differs"
    end
    assert_equal LinkPartOrganizationTool.description, RecordingLinkPartOrganizationTool.description
  end

  test "tools expose the names the model calls" do
    assert_equal "upsert_organization", UpsertOrganizationTool.new(nil).name
    assert_equal "upsert_person", UpsertPersonTool.new(nil).name
    assert_equal "upsert_part", UpsertPartTool.new(nil).name
    assert_equal "link_part_organization", LinkPartOrganizationTool.new(nil).name
    assert_equal "link_part_organization", RecordingLinkPartOrganizationTool.new(nil).name
    assert_equal "create_person_organization_type", CreatePersonOrganizationTypeTool.new(nil).name
    assert_equal "create_person_person_type", CreatePersonPersonTypeTool.new(nil).name
  end
end
