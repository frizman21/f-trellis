require "test_helper"
require "zip"

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

  # --- which snapshot the link came out of ------------------------------------

  def datum_for(source, html = "<html><body>hi</body></html>")
    buffer = Zip::OutputStream.write_buffer do |zos|
      zos.put_next_entry("page.html")
      zos.write(html)
    end
    buffer.rewind

    SourceDatum.create!(source: source, content_type: "text/html", data: buffer.read)
  end

  test "record stores the datum the link was found in" do
    datum = datum_for(@from)

    link = SourceLink.record(from: @from, to: @to, datum: datum)

    assert_equal datum, link.source_datum
  end

  # Both callers supply one, but the graph already holds rows that never can.
  test "record without a datum still works and stores null" do
    link = SourceLink.record(from: @from, to: @to)

    assert_nil link.source_datum
  end

  # The "first finder" rule. A careless implementation that assigns on every
  # call turns this column into "most recent finder" the first time a page is
  # re-crawled, which is a different fact.
  test "re-recording an edge from a newer snapshot does not move the datum" do
    first  = datum_for(@from)
    second = datum_for(@from)

    SourceLink.record(from: @from, to: @to, datum: first)
    link = SourceLink.record(from: @from, to: @to, datum: second)

    assert_equal first, link.reload.source_datum
  end

  # Deleting an old copy of a page must not delete links that are still true.
  test "destroying a datum nullifies its edges rather than removing them" do
    datum = datum_for(@from)
    SourceLink.record(from: @from, to: @to, datum: datum)

    assert_no_difference "SourceLink.count" do
      datum.destroy
    end

    link = SourceLink.find_by(from_source: @from, to_source: @to)

    assert_nil link.source_datum_id
    assert_equal @to, link.to_source
  end
end
