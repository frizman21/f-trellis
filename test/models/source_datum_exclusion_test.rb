require "test_helper"
require "zip"
require "stringio"

# Exclusions are applied by SourceDatum#extract_links, the one point both
# CrawlJob and the "Extract links" action pass through.
class SourceDatumExclusionTest < ActiveSupport::TestCase
  test "excluded links are dropped from the extracted result" do
    SourceExclusion.create!(pattern: "https://news.ycombinator.com/item?id=*")

    datum = zipped(<<~HTML)
      <a href="https://news.ycombinator.com/">Front page</a>
      <a href="https://news.ycombinator.com/item?id=8863">Comments</a>
      <a href="https://news.ycombinator.com/item?id=9999">More comments</a>
    HTML

    result = datum.extract_links

    assert_equal [ "https://news.ycombinator.com/" ], result.external
    assert_equal [ "https://news.ycombinator.com/item?id=8863",
                   "https://news.ycombinator.com/item?id=9999" ], result.excluded
  end

  # The issue's requirement: a pattern is written as an absolute URL, and the
  # hrefs it has to catch are the relative ones a site actually uses.
  test "an absolute pattern excludes relative hrefs on that host" do
    SourceExclusion.create!(pattern: "https://news.ycombinator.com/item?id=*")

    datum = zipped(<<~HTML, base_url: "https://news.ycombinator.com/news")
      <a href="item?id=8863">Relative, no leading slash</a>
      <a href="/item?id=9999">Root-relative</a>
      <a href="newest">Not excluded</a>
    HTML

    result = datum.extract_links

    assert_equal [ "https://news.ycombinator.com/newest" ], result.internal
    assert_equal [ "https://news.ycombinator.com/item?id=8863",
                   "https://news.ycombinator.com/item?id=9999" ], result.excluded
  end

  test "internal and external exclusions are reported together" do
    SourceExclusion.create!(pattern: "https://*/private/*")

    datum = zipped(<<~HTML, base_url: "https://host.test/index")
      <a href="/private/a">internal, excluded</a>
      <a href="https://other.test/private/b">external, excluded</a>
      <a href="/public">kept</a>
    HTML

    result = datum.extract_links

    assert_equal [ "https://host.test/public" ], result.internal
    assert_empty result.external
    assert_equal [ "https://host.test/private/a", "https://other.test/private/b" ],
                 result.excluded
  end

  test "nothing is excluded when no patterns are enabled" do
    SourceExclusion.create!(pattern: "https://news.ycombinator.com/item?id=*", is_enabled: false)

    datum = zipped('<a href="https://news.ycombinator.com/item?id=1">c</a>')

    result = datum.extract_links

    assert_equal [ "https://news.ycombinator.com/item?id=1" ], result.external
    assert_empty result.excluded
  end

  test "excluded reads as an empty list on an unfiltered result" do
    assert_empty LinkExtractor.call('<a href="https://example.com/a">a</a>',
                                    base_url: "https://host.test/").excluded
  end

  test "excluded is empty for a payload with no content" do
    datum = SourceDatum.new(source: sources(:one), content_type: "application/zip", data: nil)

    assert_empty datum.extract_links.excluded
  end

  private

  def zipped(html, base_url: "https://host.test/index")
    domain = Domain.find_or_create_by!(host: URI.parse(base_url).host)
    source = Source.create!(url: base_url, domain: domain)

    bytes = Zip::OutputStream.write_buffer do |zos|
      zos.put_next_entry("page.html")
      zos.write(html)
    end
    bytes.rewind

    SourceDatum.create!(source: source, content_type: "application/zip", data: bytes.read)
  end
end
