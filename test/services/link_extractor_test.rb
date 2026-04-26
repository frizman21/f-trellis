require "test_helper"

class LinkExtractorTest < ActiveSupport::TestCase
  BASE = "https://example.com/start".freeze

  test "returns empty result for blank input" do
    result = LinkExtractor.call("", base_url: BASE)
    assert_equal [], result.internal
    assert_equal [], result.external
  end

  test "extracts absolute http and https links" do
    html = <<~HTML
      <a href="https://example.com/about">about</a>
      <a href="http://example.com/contact">contact</a>
    HTML

    result = LinkExtractor.call(html, base_url: BASE)
    assert_equal ["https://example.com/about", "http://example.com/contact"], result.internal
  end

  test "resolves relative urls against the base" do
    html = <<~HTML
      <a href="/about">about</a>
      <a href="docs">docs</a>
      <a href="../up">up</a>
    HTML

    result = LinkExtractor.call(html, base_url: "https://example.com/section/page")
    assert_equal(
      ["https://example.com/about", "https://example.com/section/docs", "https://example.com/up"],
      result.internal
    )
  end

  test "resolves protocol-relative urls using base scheme" do
    html = '<a href="//other.com/x">other</a>'
    result = LinkExtractor.call(html, base_url: BASE)
    assert_equal ["https://other.com/x"], result.external
  end

  test "strips fragments from urls" do
    html = '<a href="/about#team">about</a>'
    result = LinkExtractor.call(html, base_url: BASE)
    assert_equal ["https://example.com/about"], result.internal
  end

  test "skips fragment-only navigation links" do
    html = '<a href="#section">section</a>'
    result = LinkExtractor.call(html, base_url: BASE)
    assert_equal [], result.internal
    assert_equal [], result.external
  end

  test "skips mailto, tel, and javascript schemes" do
    html = <<~HTML
      <a href="mailto:hi@example.com">email</a>
      <a href="tel:+15551234">call</a>
      <a href="javascript:void(0)">js</a>
    HTML

    result = LinkExtractor.call(html, base_url: BASE)
    assert_equal [], result.internal
    assert_equal [], result.external
  end

  test "buckets links by host into internal and external" do
    html = <<~HTML
      <a href="/local">local</a>
      <a href="https://example.com/also-local">also local</a>
      <a href="https://other.com/elsewhere">elsewhere</a>
    HTML

    result = LinkExtractor.call(html, base_url: BASE)
    assert_equal ["https://example.com/local", "https://example.com/also-local"], result.internal
    assert_equal ["https://other.com/elsewhere"], result.external
  end

  test "treats different subdomain as external" do
    html = '<a href="https://docs.example.com/x">docs</a>'
    result = LinkExtractor.call(html, base_url: BASE)
    assert_equal ["https://docs.example.com/x"], result.external
  end

  test "dedupes urls within each bucket" do
    html = <<~HTML
      <a href="/a">first</a>
      <a href="/a">second</a>
      <a href="/a#frag">third</a>
    HTML

    result = LinkExtractor.call(html, base_url: BASE)
    assert_equal ["https://example.com/a"], result.internal
  end

  test "preserves query strings" do
    html = '<a href="/search?q=ruby&page=2">search</a>'
    result = LinkExtractor.call(html, base_url: BASE)
    assert_equal ["https://example.com/search?q=ruby&page=2"], result.internal
  end

  test "ignores anchor tags without href" do
    html = '<a name="anchor">anchor</a><a href="/x">x</a>'
    result = LinkExtractor.call(html, base_url: BASE)
    assert_equal ["https://example.com/x"], result.internal
  end

  test "ignores non-anchor link sources" do
    html = <<~HTML
      <link rel="stylesheet" href="/site.css">
      <form action="/submit"></form>
      <img src="/img.png">
      <a href="/page">page</a>
    HTML

    result = LinkExtractor.call(html, base_url: BASE)
    assert_equal ["https://example.com/page"], result.internal
  end

  test "skips malformed hrefs without raising" do
    html = '<a href="http://[invalid">bad</a><a href="/good">good</a>'
    result = LinkExtractor.call(html, base_url: BASE)
    assert_equal ["https://example.com/good"], result.internal
  end

  test "host comparison is case-insensitive" do
    html = '<a href="https://EXAMPLE.com/x">x</a>'
    result = LinkExtractor.call(html, base_url: BASE)
    assert_equal ["https://EXAMPLE.com/x"], result.internal
  end
end
