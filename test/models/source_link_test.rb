require "test_helper"

class SourceLinkTest < ActiveSupport::TestCase
  setup do
    @from = sources(:one)
    @to   = sources(:two)
  end

  test "record creates an edge between two sources" do
    assert_difference "SourceLink.count", 1 do
      SourceLink.record(from: @from, to: @to)
    end

    assert_includes @from.links_to, @to
    assert_includes @to.linked_from, @from
  end

  test "record is idempotent" do
    SourceLink.record(from: @from, to: @to)

    assert_no_difference "SourceLink.count" do
      SourceLink.record(from: @from, to: @to)
    end
  end

  test "record marks only the first call as newly created" do
    assert SourceLink.record(from: @from, to: @to).previously_new_record?
    assert_not SourceLink.record(from: @from, to: @to).previously_new_record?
  end

  test "record returns nil and creates nothing for a self link" do
    assert_no_difference "SourceLink.count" do
      assert_nil SourceLink.record(from: @from, to: @from)
    end
  end

  test "record returns nil when either end is missing" do
    assert_nil SourceLink.record(from: @from, to: nil)
    assert_nil SourceLink.record(from: nil, to: @to)
  end

  test "edges are directional" do
    SourceLink.record(from: @from, to: @to)

    assert_includes @from.links_to, @to
    assert_not_includes @to.links_to, @from
  end

  test "a self link is invalid" do
    link = SourceLink.new(from_source: @from, to_source: @from)

    assert_not link.valid?
    assert_includes link.errors[:to_source], "cannot be the same source it links from"
  end

  test "duplicate edges are rejected by validation" do
    SourceLink.create!(from_source: @from, to_source: @to)

    assert_not SourceLink.new(from_source: @from, to_source: @to).valid?
  end

  test "destroying a source removes its edges in both directions" do
    SourceLink.record(from: @from, to: @to)
    SourceLink.record(from: @to, to: @from)

    assert_difference "SourceLink.count", -2 do
      @from.destroy
    end
  end
end
