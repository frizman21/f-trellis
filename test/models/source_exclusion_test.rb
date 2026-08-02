require "test_helper"

class SourceExclusionTest < ActiveSupport::TestCase
  test "a pattern with no wildcard matches only that exact URL" do
    exclusion = SourceExclusion.create!(pattern: "https://news.ycombinator.com/item?id=8863")

    assert exclusion.matches?("https://news.ycombinator.com/item?id=8863")
    assert_not exclusion.matches?("https://news.ycombinator.com/item?id=8864")
    assert_not exclusion.matches?("https://news.ycombinator.com/item?id=8863/replies")
  end

  test "a wildcard stands for any run of characters" do
    exclusion = SourceExclusion.create!(pattern: "https://news.ycombinator.com/item?id=*")

    assert exclusion.matches?("https://news.ycombinator.com/item?id=8863")
    assert exclusion.matches?("https://news.ycombinator.com/item?id=44444444")
    assert_not exclusion.matches?("https://news.ycombinator.com/")
    assert_not exclusion.matches?("https://news.ycombinator.com/newest")
  end

  test "a wildcard matches an empty run" do
    exclusion = SourceExclusion.create!(pattern: "https://example.com/docs/*")

    assert exclusion.matches?("https://example.com/docs/")
  end

  test "patterns are anchored at both ends" do
    exclusion = SourceExclusion.create!(pattern: "https://example.com/a")

    assert_not exclusion.matches?("https://example.com/a/b"),
      "an unanchored match would excluded the whole subtree of every pattern"
    assert_not exclusion.matches?("https://mirror.example.com/a")
  end

  test "a wildcard works in the host as well as the path" do
    exclusion = SourceExclusion.create!(pattern: "https://*.wikipedia.org/wiki/Special:*")

    assert exclusion.matches?("https://en.wikipedia.org/wiki/Special:RecentChanges")
    assert exclusion.matches?("https://de.wikipedia.org/wiki/Special:Random")
    assert_not exclusion.matches?("https://en.wikipedia.org/wiki/NASA")
  end

  test "matching ignores case" do
    exclusion = SourceExclusion.create!(pattern: "https://News.YCombinator.com/Item?id=*")

    assert exclusion.matches?("https://news.ycombinator.com/item?id=1")
  end

  test "regex metacharacters in a pattern are literal" do
    exclusion = SourceExclusion.create!(pattern: "https://example.com/a.b?x=1")

    assert exclusion.matches?("https://example.com/a.b?x=1")
    assert_not exclusion.matches?("https://example.com/axb?x=1"),
      "a bare dot must not behave as a regex wildcard"
  end

  test "a matched URL is normalized before comparison" do
    exclusion = SourceExclusion.create!(pattern: "https://news.ycombinator.com/item?id=*")

    # A fragment is stripped and a missing scheme filled in, the same treatment
    # link extraction gives a URL before it reaches here.
    assert exclusion.matches?("https://news.ycombinator.com/item?id=1#comment-2")
    assert exclusion.matches?("news.ycombinator.com/item?id=1")
  end

  test "matches? is false for text that is not a URL" do
    exclusion = SourceExclusion.create!(pattern: "https://example.com/*")

    assert_not exclusion.matches?("")
    assert_not exclusion.matches?(nil)
    assert_not exclusion.matches?("mailto:someone@example.com")
  end

  test "the pattern is normalized on save" do
    exclusion = SourceExclusion.create!(pattern: "  news.ycombinator.com/item?id=*#top  ")

    assert_equal "https://news.ycombinator.com/item?id=*", exclusion.pattern
  end

  test "a pattern that is not a URL is rejected" do
    exclusion = SourceExclusion.new(pattern: "not a url")

    assert_not exclusion.valid?
    assert_includes exclusion.errors[:pattern].to_sentence, "must be a URL"
  end

  test "a blank pattern is rejected" do
    assert_not SourceExclusion.new(pattern: "  ").valid?
  end

  test "patterns are unique" do
    SourceExclusion.create!(pattern: "https://example.com/x/*")
    duplicate = SourceExclusion.new(pattern: "https://example.com/x/*")

    assert_not duplicate.valid?
  end

  test "uniqueness applies after normalization" do
    SourceExclusion.create!(pattern: "https://example.com/x/*")
    duplicate = SourceExclusion.new(pattern: "example.com/x/*")

    assert_not duplicate.valid?,
      "the same rule written two ways must not become two rows"
  end

  test ".partition_urls splits kept from excluded" do
    SourceExclusion.create!(pattern: "https://news.ycombinator.com/item?id=*")

    kept, excluded = SourceExclusion.partition_urls([
      "https://news.ycombinator.com/",
      "https://news.ycombinator.com/item?id=1",
      "https://example.com/page",
      "https://news.ycombinator.com/item?id=2"
    ])

    assert_equal [ "https://news.ycombinator.com/", "https://example.com/page" ], kept
    assert_equal [ "https://news.ycombinator.com/item?id=1",
                   "https://news.ycombinator.com/item?id=2" ], excluded
  end

  test ".partition_urls keeps everything when no patterns exist" do
    kept, excluded = SourceExclusion.partition_urls([ "https://example.com/a" ])

    assert_equal [ "https://example.com/a" ], kept
    assert_empty excluded
  end

  test "a disabled pattern is not applied" do
    SourceExclusion.create!(pattern: "https://news.ycombinator.com/item?id=*", is_enabled: false)

    kept, excluded = SourceExclusion.partition_urls([ "https://news.ycombinator.com/item?id=1" ])

    assert_equal [ "https://news.ycombinator.com/item?id=1" ], kept
    assert_empty excluded
  end

  test "#matching_source_count counts sources already in the database" do
    exclusion = SourceExclusion.create!(pattern: "https://example.com/*")

    assert_equal Source.where("url LIKE 'https://example.com/%'").count,
                 exclusion.matching_source_count
    assert_operator exclusion.matching_source_count, :>, 0
  end

  test "#matching_source_count treats LIKE metacharacters in a pattern as literal" do
    domain = Domain.find_or_create_by!(host: "example.com")
    Source.create!(url: "https://example.com/a_b", domain: domain)
    Source.create!(url: "https://example.com/axb", domain: domain)

    exclusion = SourceExclusion.create!(pattern: "https://example.com/a_b")

    assert_equal 1, exclusion.matching_source_count,
      "a literal _ in the pattern must not behave as a single-character SQL wildcard"
  end

  test "#matching_source_count handles a percent-encoded pattern" do
    domain = Domain.find_or_create_by!(host: "example.com")
    Source.create!(url: "https://example.com/100%25-guide", domain: domain)
    Source.create!(url: "https://example.com/100x-guide", domain: domain)

    exclusion = SourceExclusion.create!(pattern: "https://example.com/100%25-guide")

    assert_equal 1, exclusion.matching_source_count,
      "the % of an escape sequence must not behave as a SQL wildcard"
  end
end
