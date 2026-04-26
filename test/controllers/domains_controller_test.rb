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
