require "test_helper"

class SourceTest < ActiveSupport::TestCase
  test "auto-creates a domain from the url on save" do
    assert_difference -> { Domain.count } => 1 do
      source = Source.create!(url: "https://newhost.example/path", description: "x")
      assert_equal "newhost.example", source.domain.host
    end
  end

  test "reuses an existing domain matching the url host" do
    Domain.create!(host: "reuse.test")
    assert_no_difference -> { Domain.count } do
      source = Source.create!(url: "https://reuse.test/page", description: "x")
      assert_equal "reuse.test", source.domain.host
    end
  end

  test "downcases host when deriving the domain" do
    source = Source.create!(url: "https://MixedCase.Example/path", description: "x")
    assert_equal "mixedcase.example", source.domain.host
  end

  test "explicit domain assignment is not overridden" do
    explicit = Domain.create!(host: "explicit.test")
    source = Source.create!(url: "https://other.test/page", domain: explicit, description: "x")
    assert_equal "explicit.test", source.domain.host
  end

  test "fails validation when url has no parseable host" do
    source = Source.new(url: "not a url at all", description: "x")
    assert_not source.valid?
    assert_includes source.errors[:domain], "must exist"
  end

  test "parent_source is optional" do
    source = Source.new(url: "https://example.com/no-parent")

    assert source.valid?
    assert_nil source.parent_source
  end

  test "child_sources reports the sources discovered from this one" do
    parent = sources(:one)
    child  = Source.create!(url: "https://example.com/child", parent_source: parent)

    assert_equal parent, child.parent_source
    assert_includes parent.child_sources, child
  end

  test "destroying a parent nullifies its children rather than deleting them" do
    parent = Source.create!(url: "https://example.com/parent")
    child  = Source.create!(url: "https://example.com/child", parent_source: parent)

    parent.destroy

    assert Source.exists?(child.id), "expected the child source to survive"
    assert_nil child.reload.parent_source_id
  end
end
