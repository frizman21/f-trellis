require "test_helper"

class RobotsDirectivesTest < ActiveSupport::TestCase
  def meta(content, name: "robots")
    RobotsDirectives.from_html(%(<html><head><meta name="#{name}" content="#{content}"></head><body></body></html>))
  end

  test "an absent tag permits everything" do
    directives = RobotsDirectives.from_html("<html><head></head><body></body></html>")

    assert directives.follow?
    assert directives.index?
  end

  test "index, follow permits everything" do
    directives = meta("index, follow")

    assert directives.follow?
    assert directives.index?
  end

  # The distinction the whole card turns on.
  test "noindex does not imply nofollow, and nofollow does not imply noindex" do
    assert meta("noindex").follow?
    assert meta("noindex").noindex?

    assert meta("nofollow").index?
    assert meta("nofollow").nofollow?
  end

  test "noindex, nofollow forbids both" do
    directives = meta("noindex, nofollow")

    assert directives.nofollow?
    assert directives.noindex?
  end

  test "none forbids both" do
    directives = meta("none")

    assert directives.nofollow?
    assert directives.noindex?
  end

  test "casing and whitespace are tolerated" do
    directives = meta("  NOINDEX ,  NoFollow  ")

    assert directives.nofollow?
    assert directives.noindex?
  end

  test "a malformed or empty content attribute does not raise" do
    assert meta("").index?
    assert meta(",,,").index?
    assert RobotsDirectives.from_html("not html at all").index?
    assert RobotsDirectives.from_html(nil).index?
  end

  # The same precedence robots.txt group selection uses.
  test "an agent-specific meta outranks the generic one" do
    html = <<~HTML
      <html><head>
        <meta name="robots" content="noindex">
        <meta name="f-agents" content="index">
      </head><body></body></html>
    HTML

    assert RobotsDirectives.from_html(html).index?
  end

  test "another agent's meta is ignored" do
    html = <<~HTML
      <html><head>
        <meta name="robots" content="index">
        <meta name="some-other-bot" content="noindex">
      </head><body></body></html>
    HTML

    assert RobotsDirectives.from_html(html).index?
  end

  test "the header form parses the same vocabulary as the meta form" do
    assert RobotsDirectives.from_content("noindex").noindex?
    assert RobotsDirectives.from_content("none").nofollow?
    assert RobotsDirectives.from_content("index, follow").index?
  end

  test "merging takes the more restrictive of the two, since either is the site asking" do
    permissive = RobotsDirectives.from_content("index, follow")
    restrictive = RobotsDirectives.from_content("noindex")

    assert permissive.merge(restrictive).noindex?
    assert restrictive.merge(permissive).noindex?
    assert permissive.merge(nil).index?
  end
end
