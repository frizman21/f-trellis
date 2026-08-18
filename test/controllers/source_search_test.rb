require "test_helper"

class SourceSearchTest < ActionDispatch::IntegrationTest
  def results
    JSON.parse(response.body)
  end

  test "matches on url" do
    get search_sources_path, params: { q: "example.com" }

    assert_response :success
    assert results.any?
    assert(results.all? { |s| s["url"].include?("example.com") })
  end

  test "matches on description" do
    source = Source.create!(url: "https://searchable.test/page",
                            description: "A distinctive haystack needle",
                            domain: Domain.for_url("https://searchable.test/page"))

    get search_sources_path, params: { q: "haystack" }

    assert_includes results.map { |s| s["id"] }, source.id
  end

  test "is case-insensitive" do
    get search_sources_path, params: { q: "EXAMPLE.COM" }

    assert results.any?
  end

  # The endpoint answers a keystroke, so an unbounded result set is not an option.
  test "caps how many it returns" do
    domain = Domain.for_url("https://bulk.test/0")
    (SourcesController::LOOKUP_LIMIT + 5).times do |i|
      Source.create!(url: "https://bulk.test/needle-#{i}", domain: domain)
    end

    get search_sources_path, params: { q: "needle" }

    assert_equal SourcesController::LOOKUP_LIMIT, results.size
  end

  test "a blank query returns nothing rather than everything" do
    get search_sources_path, params: { q: "" }

    assert_empty results
  end

  test "returns the id, url and description each result needs to be shown and chosen" do
    get search_sources_path, params: { q: "example.com" }

    assert_equal %w[description id url], results.first.keys.sort
  end
end
