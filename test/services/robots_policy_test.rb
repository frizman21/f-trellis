require "test_helper"

class RobotsPolicyTest < ActiveSupport::TestCase
  def policy(body, agent: "f-agents")
    RobotsPolicy.parse(body, agent: agent)
  end

  test "a disallowed prefix covers everything under it" do
    p = policy(<<~ROBOTS)
      User-agent: *
      Disallow: /private
    ROBOTS

    assert p.disallowed?("/private")
    assert p.disallowed?("/private/page")
    assert p.allowed?("/public")
  end

  # RFC 9309: an empty Disallow is how a site says "nothing is off limits".
  test "an empty Disallow allows everything" do
    p = policy(<<~ROBOTS)
      User-agent: *
      Disallow:
    ROBOTS

    assert p.allowed?("/anything")
  end

  test "the longest matching pattern wins" do
    p = policy(<<~ROBOTS)
      User-agent: *
      Disallow: /a
      Allow: /a/b
    ROBOTS

    assert p.allowed?("/a/b")
    assert p.disallowed?("/a/c")
  end

  test "allow wins when two patterns are the same length" do
    p = policy(<<~ROBOTS)
      User-agent: *
      Disallow: /page
      Allow: /page
    ROBOTS

    assert p.allowed?("/page")
  end

  test "a group naming us is preferred and the wildcard group is then ignored" do
    p = policy(<<~ROBOTS)
      User-agent: *
      Disallow: /

      User-agent: f-agents
      Disallow: /admin
    ROBOTS

    assert p.allowed?("/anything"), "the * group must not apply once we are named"
    assert p.disallowed?("/admin")
  end

  test "the wildcard group applies when we are not named" do
    p = policy(<<~ROBOTS)
      User-agent: someone-else
      Disallow: /

      User-agent: *
      Disallow: /private
    ROBOTS

    assert p.allowed?("/public")
    assert p.disallowed?("/private")
  end

  test "user-agent matching is case-insensitive" do
    p = policy(<<~ROBOTS)
      User-agent: F-Agents
      Disallow: /nope
    ROBOTS

    assert p.disallowed?("/nope")
  end

  test "consecutive user-agent lines share one group" do
    p = policy(<<~ROBOTS)
      User-agent: f-agents
      User-agent: other-bot
      Disallow: /shared
    ROBOTS

    assert p.disallowed?("/shared")
  end

  test "a star wildcard matches any run of characters" do
    p = policy(<<~ROBOTS)
      User-agent: *
      Disallow: /*/private
    ROBOTS

    assert p.disallowed?("/a/private")
    assert p.disallowed?("/deeply/nested/private")
    assert p.allowed?("/private")
  end

  test "a dollar anchors the end of the path" do
    p = policy(<<~ROBOTS)
      User-agent: *
      Disallow: /*.pdf$
    ROBOTS

    assert p.disallowed?("/doc.pdf")
    assert p.allowed?("/doc.pdf.html")
  end

  test "comments and unknown directives are ignored rather than fatal" do
    p = policy(<<~ROBOTS)
      # a comment
      User-agent: *   # trailing comment
      Disallow: /private
      Some-Unknown-Field: whatever
      not even a field line
    ROBOTS

    assert p.disallowed?("/private")
    assert p.allowed?("/public")
  end

  test "an empty or blank file allows everything" do
    assert policy("").allowed?("/anything")
    assert policy("   \n\n").allowed?("/anything")
  end

  test "rules with no group above them are ignored" do
    p = policy(<<~ROBOTS)
      Disallow: /orphan
    ROBOTS

    assert p.allowed?("/orphan")
  end

  test "crawl delay is read from the group that applies" do
    p = policy(<<~ROBOTS)
      User-agent: *
      Crawl-delay: 10

      User-agent: f-agents
      Crawl-delay: 3
    ROBOTS

    assert_equal 3, p.crawl_delay
  end

  test "crawl delay is nil when the file does not ask for one" do
    assert_nil policy("User-agent: *\nDisallow: /x\n").crawl_delay
  end

  test "a fractional crawl delay rounds up rather than down" do
    assert_equal 1, policy("User-agent: *\nCrawl-delay: 0.5\n").crawl_delay
  end

  # Site-wide, so it is read even from a file whose rules are not ours.
  test "sitemap directives are collected regardless of group" do
    p = policy(<<~ROBOTS)
      Sitemap: https://example.com/sitemap.xml

      User-agent: someone-else
      Disallow: /
      Sitemap: https://example.com/news.xml
    ROBOTS

    assert_equal [ "https://example.com/sitemap.xml", "https://example.com/news.xml" ], p.sitemaps
  end

  test "allow_all permits everything and deny_all permits nothing" do
    assert RobotsPolicy.allow_all.allowed?("/anything")
    assert RobotsPolicy.deny_all.disallowed?("/anything")
    assert RobotsPolicy.deny_all.disallowed?("/")
  end

  test "path_for takes the path and query a server actually sees" do
    assert_equal "/a/b", RobotsPolicy.path_for("https://example.com/a/b")
    assert_equal "/", RobotsPolicy.path_for("https://example.com")
    assert_equal "/s?q=1", RobotsPolicy.path_for("https://example.com/s?q=1")
  end

  test "patterns match against the query string too" do
    p = policy(<<~ROBOTS)
      User-agent: *
      Disallow: /item?id=
    ROBOTS

    assert p.disallowed?(RobotsPolicy.path_for("https://example.com/item?id=5"))
    assert p.allowed?(RobotsPolicy.path_for("https://example.com/item"))
  end
end
