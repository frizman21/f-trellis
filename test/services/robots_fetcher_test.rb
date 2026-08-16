require "test_helper"

class RobotsFetcherTest < ActiveSupport::TestCase
  # Same alias_method stubbing as the rest of the suite, against the same kind
  # of single-request seam FetchSourceJob exposes.
  def with_robots_response(code: "200", body: "", raises: nil)
    requests = []

    RobotsFetcher.singleton_class.class_eval do
      alias_method :request_without_stub, :request
      define_method(:request) do |uri|
        requests << uri.to_s
        raise raises if raises

        FakeHttp.build_response(code: code, body: body)
      end
    end

    yield requests
  ensure
    RobotsFetcher.singleton_class.class_eval do
      remove_method :request
      alias_method :request, :request_without_stub
      remove_method :request_without_stub
    end
  end

  setup { @domain = Domain.create!(host: "robots.test") }

  test "a 200 stores the file and stamps when it was read" do
    with_robots_response(body: "User-agent: *\nDisallow: /private\n") do |requests|
      policy = RobotsFetcher.policy_for(@domain)

      assert_equal [ "https://robots.test/robots.txt" ], requests
      assert policy.disallowed?("/private")
    end

    assert_equal "ok", @domain.reload.robots_status
    assert_not_nil @domain.robots_fetched_at
    assert_includes @domain.robots_txt, "Disallow: /private"
  end

  test "a 404 means the site asked for nothing" do
    with_robots_response(code: "404") do
      assert RobotsFetcher.policy_for(@domain).allowed?("/anything")
    end

    assert_equal "absent", @domain.reload.robots_status
  end

  # The conservative branch, and the one most likely to surprise.
  test "a 500 puts the whole site off limits" do
    with_robots_response(code: "500") do
      assert RobotsFetcher.policy_for(@domain).disallowed?("/anything")
    end

    assert_equal "unreachable", @domain.reload.robots_status
  end

  test "a timeout is treated as unreachable rather than raising into the crawl" do
    with_robots_response(raises: Net::OpenTimeout.new) do
      assert RobotsFetcher.policy_for(@domain).disallowed?("/anything")
    end

    assert_equal "unreachable", @domain.reload.robots_status
  end

  test "a crawl delay from the file is recorded on the domain" do
    with_robots_response(body: "User-agent: *\nCrawl-delay: 7\n") do
      RobotsFetcher.policy_for(@domain)
    end

    assert_equal 7, @domain.reload.robots_crawl_delay_seconds
  end

  test "a domain read recently is not read again" do
    with_robots_response(body: "User-agent: *\nDisallow: /a\n") do |requests|
      RobotsFetcher.policy_for(@domain)
      RobotsFetcher.policy_for(@domain)

      assert_equal 1, requests.size
    end
  end

  test "a domain read more than a day ago is read again" do
    with_robots_response(body: "User-agent: *\nDisallow: /a\n") do |requests|
      RobotsFetcher.policy_for(@domain)
      @domain.update_columns(robots_fetched_at: 25.hours.ago)
      RobotsFetcher.policy_for(@domain)

      assert_equal 2, requests.size
    end
  end

  test "a nil domain permits everything rather than raising" do
    assert RobotsFetcher.policy_for(nil).allowed?("/anything")
  end

  test "the request identifies the crawler the same way a page fetch does" do
    with_robots_response(body: "") do
      RobotsFetcher.policy_for(@domain)
    end

    # The token a site would write a rule against must be the one we send.
    assert_equal "f-agents", CrawlerIdentity.product_token
  end
end
