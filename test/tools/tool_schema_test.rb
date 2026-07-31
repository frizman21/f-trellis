require "test_helper"
require "ruby_llm/schema"

# The params DSL is only evaluated when a request is built, so a malformed
# schema raises at call time against a live provider rather than in the tools'
# own tests. These assertions compile each tool's schema up front.
class ToolSchemaTest < ActiveSupport::TestCase
  BATCHED_TOOLS = {
    UpsertOrganizationTool => "organizations",
    UpsertPersonTool => "people"
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

  test "tools expose the names the model calls" do
    assert_equal "upsert_organization", UpsertOrganizationTool.new(nil).name
    assert_equal "upsert_person", UpsertPersonTool.new(nil).name
  end
end
