require "test_helper"
require "zlib"
require "stringio"

class SitemapReaderTest < ActiveSupport::TestCase
  # `pages` maps a URL to a body, or to a status symbol. Stubs the same kind of
  # single-request seam the rest of the suite uses.
  def with_sitemaps(pages)
    requested = []

    SitemapReader.singleton_class.class_eval do
      alias_method :request_without_stub, :request
      define_method(:request) do |uri|
        requested << uri.to_s
        body = pages[uri.to_s]

        FakeHttp.build_response(code: body.nil? ? "404" : "200", body: body.to_s)
      end
    end

    yield requested
  ensure
    SitemapReader.singleton_class.class_eval do
      remove_method :request
      alias_method :request, :request_without_stub
      remove_method :request_without_stub
    end
  end

  def urlset(*entries)
    body = entries.map do |url, lastmod|
      lastmod ? "<url><loc>#{url}</loc><lastmod>#{lastmod}</lastmod></url>" : "<url><loc>#{url}</loc></url>"
    end.join

    %(<?xml version="1.0" encoding="UTF-8"?><urlset>#{body}</urlset>)
  end

  test "a urlset returns its locations in order" do
    body = urlset([ "https://s.test/a" ], [ "https://s.test/b" ])

    with_sitemaps("https://s.test/sitemap.xml" => body) do
      result = SitemapReader.call("https://s.test/sitemap.xml")

      assert result.success?
      assert_equal [ "https://s.test/a", "https://s.test/b" ], result.entries.map(&:url)
    end
  end

  test "lastmod is parsed when present and nil when absent or malformed" do
    body = urlset([ "https://s.test/a", "2026-03-04" ], [ "https://s.test/b" ], [ "https://s.test/c", "nonsense" ])

    with_sitemaps("https://s.test/sitemap.xml" => body) do
      entries = SitemapReader.call("https://s.test/sitemap.xml").entries

      assert_equal Date.new(2026, 3, 4), entries[0].lastmod.to_date
      assert_nil entries[1].lastmod
      assert_nil entries[2].lastmod
    end
  end

  test "a sitemap index resolves its children" do
    index = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <sitemapindex>
        <sitemap><loc>https://s.test/one.xml</loc></sitemap>
        <sitemap><loc>https://s.test/two.xml</loc></sitemap>
      </sitemapindex>
    XML

    pages = {
      "https://s.test/sitemap.xml" => index,
      "https://s.test/one.xml" => urlset([ "https://s.test/a" ]),
      "https://s.test/two.xml" => urlset([ "https://s.test/b" ])
    }

    with_sitemaps(pages) do
      entries = SitemapReader.call("https://s.test/sitemap.xml").entries

      assert_equal [ "https://s.test/a", "https://s.test/b" ], entries.map(&:url)
    end
  end

  # Indexes can nest indefinitely; a broken or hostile one must not.
  test "an index nested beyond one level is not followed" do
    index = '<?xml version="1.0"?><sitemapindex><sitemap><loc>https://s.test/inner.xml</loc></sitemap></sitemapindex>'
    inner = '<?xml version="1.0"?><sitemapindex><sitemap><loc>https://s.test/deep.xml</loc></sitemap></sitemapindex>'

    pages = {
      "https://s.test/sitemap.xml" => index,
      "https://s.test/inner.xml" => inner,
      "https://s.test/deep.xml" => urlset([ "https://s.test/too-deep" ])
    }

    with_sitemaps(pages) do |requested|
      entries = SitemapReader.call("https://s.test/sitemap.xml").entries

      assert_empty entries
      assert_not_includes requested, "https://s.test/deep.xml"
    end
  end

  test "a gzipped sitemap is decompressed" do
    raw = urlset([ "https://s.test/zipped" ])
    buffer = StringIO.new
    Zlib::GzipWriter.wrap(buffer) { |gz| gz.write(raw) }

    with_sitemaps("https://s.test/sitemap.xml.gz" => buffer.string) do
      entries = SitemapReader.call("https://s.test/sitemap.xml.gz").entries

      assert_equal [ "https://s.test/zipped" ], entries.map(&:url)
    end
  end

  test "malformed XML returns empty with a reason rather than raising" do
    with_sitemaps("https://s.test/sitemap.xml" => "this is not xml at all <<<") do
      result = SitemapReader.call("https://s.test/sitemap.xml")

      assert_empty result.entries
      assert_not_nil result.error
    end
  end

  # Nothing matched is an answer; could not read is a failure.
  test "an empty urlset succeeds with no entries" do
    with_sitemaps("https://s.test/sitemap.xml" => '<?xml version="1.0"?><urlset></urlset>') do
      result = SitemapReader.call("https://s.test/sitemap.xml")

      assert result.success?
      assert_empty result.entries
      assert_not result.any?
    end
  end

  test "a 404 is a stated absence rather than an exception" do
    with_sitemaps({}) do
      result = SitemapReader.call("https://s.test/sitemap.xml")

      assert_empty result.entries
      assert_not_nil result.error
    end
  end

  test "more urls than the cap returns exactly the cap" do
    entries = (SitemapReader::MAX_ENTRIES + 50).times.map { |i| [ "https://s.test/p#{i}" ] }

    with_sitemaps("https://s.test/sitemap.xml" => urlset(*entries)) do
      assert_equal SitemapReader::MAX_ENTRIES, SitemapReader.call("https://s.test/sitemap.xml").entries.size
    end
  end

  test "a non-http scheme is refused" do
    with_sitemaps({}) do |requested|
      assert_empty SitemapReader.call("ftp://s.test/sitemap.xml").entries
      assert_empty requested
    end
  end

  # --- where sitemaps are declared -------------------------------------------

  def stub_policy(policy)
    RobotsFetcher.singleton_class.class_eval do
      alias_method :policy_for_without_stub, :policy_for
      define_method(:policy_for) { |_domain, **| policy }
    end
    yield
  ensure
    RobotsFetcher.singleton_class.class_eval do
      remove_method :policy_for
      alias_method :policy_for, :policy_for_without_stub
      remove_method :policy_for_without_stub
    end
  end

  test "robots.txt Sitemap directives are preferred over the conventional path" do
    domain = Domain.create!(host: "declared.test")
    policy = RobotsPolicy.parse("Sitemap: https://declared.test/custom.xml\n", agent: "f-agents")

    stub_policy(policy) do
      assert_equal [ "https://declared.test/custom.xml" ], SitemapReader.locations_for(domain)
    end
  end

  test "the conventional path is used when robots.txt declares none" do
    domain = Domain.create!(host: "plain.test")

    stub_policy(RobotsPolicy.allow_all) do
      assert_equal [ "https://plain.test/sitemap.xml" ], SitemapReader.locations_for(domain)
    end
  end
end
