require "test_helper"

# The one place a payload becomes a row. Extracted from FetchSourceJob in #70 so
# the proof of concept's apply stage can store content it fetched earlier
# without a second copy of these rules.
#
# The property that matters throughout: what goes in comes back out unchanged.
# Every reader downstream — Source#latest_text, LearningSet, SkillTriage, the
# PDF parser — sees SourceDatum#raw_bytes and nothing else.
class SourcePayloadTest < ActiveSupport::TestCase
  setup { @source = sources(:one) }

  test "stored HTML reads back byte for byte" do
    html = "<html><body><p>Rocketdyne F-1</p></body></html>"

    datum = SourcePayload.store(source: @source, content: html, content_type: "text/html")

    assert_equal html, datum.reload.raw_bytes
    assert_equal "text/html", datum.content_type
  end

  # A PDF must survive this untouched: the parser sees these bytes and nothing
  # else, and a single re-encoded byte makes it unreadable.
  test "stored PDF bytes are unchanged" do
    bytes = File.binread(file_fixture("two_page_text.pdf"))

    datum = SourcePayload.store(source: @source, content: bytes, content_type: "application/pdf")

    assert_equal bytes.bytesize, datum.reload.raw_bytes.bytesize
    assert_equal Digest::SHA256.hexdigest(bytes), Digest::SHA256.hexdigest(datum.raw_bytes)
  end

  test "the stored payload is readable as text by everything downstream" do
    SourcePayload.store(source: @source, content: "<html><body><h1>Saturn V</h1></body></html>")

    assert_equal "Saturn V", @source.reload.latest_text
  end

  # --- the entry name --------------------------------------------------------

  test "the entry is named from the url and carries the payload's extension" do
    assert_equal "page-one.html", SourcePayload.entry_name_for(@source, "text/html")
  end

  test "a pdf is not named .html" do
    assert_equal "page-one.pdf", SourcePayload.entry_name_for(@source, "application/pdf")
  end

  test "an existing extension is not doubled" do
    source = Source.create!(url: "https://example.com/report.html")

    assert_equal "report.html", SourcePayload.entry_name_for(source, "text/html")
  end

  # "https://example.com/" has a path of "/" and offers no filename at all.
  test "a url with no filename falls back to the source id" do
    source = Source.create!(url: "https://example.com/")

    assert_equal "source_#{source.id}.html", SourcePayload.entry_name_for(source, "text/html")
  end

  # A server sending something unrecognised is not a reason to refuse its page.
  test "an unknown content type falls back to the html suffixes" do
    assert_equal "page-one.html", SourcePayload.entry_name_for(@source, "application/octet-stream")
    assert_equal "page-one.html", SourcePayload.entry_name_for(@source, nil)
  end

  test "a blank content type stores as html rather than as blank" do
    datum = SourcePayload.store(source: @source, content: "<p>hi</p>", content_type: "")

    assert_equal "text/html", datum.content_type
  end

  # --- history ---------------------------------------------------------------

  # SourceDatum is a record of what a page said when, and SourceLink hangs off
  # individual snapshots. Storing twice must not overwrite the first.
  test "storing again adds a snapshot rather than replacing one" do
    first = SourcePayload.store(source: @source, content: "<p>before</p>")
    second = SourcePayload.store(source: @source, content: "<p>after</p>")

    assert_not_equal first.id, second.id
    assert_equal "<p>before</p>", first.reload.raw_bytes
    assert_equal "<p>after</p>", second.reload.raw_bytes
  end
end
