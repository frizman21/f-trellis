require "test_helper"

class DomainsControllerTest < ActionDispatch::IntegrationTest
  test "index renders" do
    get domains_path
    assert_response :success
    assert_select "h1", "Domains"
    assert_select "td", text: "example.com"
    assert_select "td", text: "other.com"
  end

  test "index filters by host substring" do
    get domains_path, params: { q: "example" }
    assert_response :success
    assert_select "td", text: "example.com"
    assert_select "td", text: "other.com", count: 0
  end

  test "index filter is case-insensitive" do
    get domains_path, params: { q: "EXAMPLE" }
    assert_response :success
    assert_select "td", text: "example.com"
  end

  test "index shows empty-state message when filter matches nothing" do
    get domains_path, params: { q: "no-such-host" }
    assert_response :success
    assert_match(/No domains match/, response.body)
  end

  test "index links each host to its page" do
    get domains_path

    assert_select "a[href=?]", domain_path(domains(:example_com)), text: "example.com"
  end

  # --- show ------------------------------------------------------------------

  def crawl(domain, url, outcome: "ok", status_code: 200, at: nil)
    record = CrawlRecord.create!(url: url, domain: domain, outcome: outcome, status_code: status_code)
    record.update_columns(created_at: at) if at
    record
  end

  test "show lists the crawl records for the domain" do
    domain = domains(:example_com)
    crawl(domain, "https://example.com/one")
    crawl(domain, "https://example.com/two", outcome: "http_error", status_code: 404)

    get domain_path(domain)

    assert_response :success
    assert_select "h1", "example.com"
    assert_match(/example\.com\/one/, response.body)
    assert_match(/example\.com\/two/, response.body)
    assert_match(/404/, response.body)
  end

  test "show lists the most recent crawl first" do
    domain = domains(:example_com)
    crawl(domain, "https://example.com/older", at: 3.days.ago)
    crawl(domain, "https://example.com/newer", at: 1.hour.ago)

    get domain_path(domain)

    assert_operator response.body.index("example.com/newer"), :<,
                    response.body.index("example.com/older")
  end

  # The assertion that fails if the query ever regresses to matching URL
  # prefixes instead of the foreign key.
  test "show does not leak another domain's records" do
    crawl(domains(:other_com), "https://other.com/secret")

    get domain_path(domains(:example_com))

    assert_response :success
    assert_no_match(/other\.com\/secret/, response.body)
  end

  test "show counts failures without counting successes or skips" do
    domain = domains(:example_com)
    crawl(domain, "https://example.com/a")
    crawl(domain, "https://example.com/b", outcome: "skipped", status_code: nil)
    crawl(domain, "https://example.com/c", outcome: "http_error", status_code: 500)
    crawl(domain, "https://example.com/d", outcome: "no_response", status_code: nil)

    get domain_path(domain)

    assert_match(/4 pages crawled/, response.body)
    assert_match(/2 did not come back/, response.body)
  end

  test "show says so when nothing has been crawled rather than showing an empty table" do
    get domain_path(domains(:example_com))

    assert_response :success
    assert_match(/No crawls recorded/, response.body)
    assert_select "table", count: 0
  end

  test "show renders a record that has no status code" do
    crawl(domains(:example_com), "https://example.com/timeout", outcome: "no_response", status_code: nil)

    get domain_path(domains(:example_com))

    assert_response :success
    assert_match(/No response/, response.body)
  end

  test "show paginates a long crawl history" do
    domain = domains(:example_com)
    30.times { |i| crawl(domain, "https://example.com/p#{i}") }

    get domain_path(domain)

    assert_response :success
    assert_select "tbody tr", 25
    assert_match(/Showing 25 of 30/, response.body)
  end

  test "edit renders the form" do
    get edit_domain_path(domains(:example_com))
    assert_response :success
    assert_select "input[name=?]", "domain[min_crawl_delay_seconds]"
  end

  test "update saves the crawl delay and redirects" do
    domain = domains(:example_com)
    patch domain_path(domain), params: { domain: { min_crawl_delay_seconds: 5 } }
    assert_redirected_to domains_path
    assert_equal 5, domain.reload.min_crawl_delay_seconds
  end

  test "update clears the crawl delay when set to blank" do
    domain = domains(:example_com)
    patch domain_path(domain), params: { domain: { min_crawl_delay_seconds: "" } }
    assert_redirected_to domains_path
    assert_nil domain.reload.min_crawl_delay_seconds
  end

  test "update rejects negative values and re-renders edit" do
    domain = domains(:example_com)
    patch domain_path(domain), params: { domain: { min_crawl_delay_seconds: -1 } }
    assert_response :unprocessable_entity
    assert_equal 1, domain.reload.min_crawl_delay_seconds
  end
end
