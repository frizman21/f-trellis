require "test_helper"

class CrawlRecordTest < ActiveSupport::TestCase
  test "requires a url" do
    record = CrawlRecord.new

    assert_not record.valid?
    assert_includes record.errors[:url], "can't be blank"
  end

  test "records when it was crawled" do
    record = CrawlRecord.create!(url: "https://example.com/x")

    assert_not_nil record.created_at
  end

  test "derives its domain from the url" do
    record = CrawlRecord.create!(url: "https://example.com/page")

    assert_equal "example.com", record.domain.host
  end

  test "reuses a domain already known rather than creating a second" do
    first = CrawlRecord.create!(url: "https://reuse.test/a")

    assert_no_difference -> { Domain.count } do
      second = CrawlRecord.create!(url: "https://reuse.test/b")

      assert_equal first.domain_id, second.domain_id
    end
  end

  test "host casing does not split one site across two domains" do
    upper = CrawlRecord.create!(url: "HTTPS://Casing.TEST/a")
    lower = CrawlRecord.create!(url: "https://casing.test/b")

    assert_equal lower.domain_id, upper.domain_id
  end

  test "an explicitly supplied domain is not overwritten" do
    domain = domains(:other_com)
    record = CrawlRecord.create!(url: "https://example.com/page", domain: domain)

    assert_equal domain, record.domain
  end

  test "status_code may be nil, because a request that got no response has none" do
    record = CrawlRecord.create!(url: "https://example.com/x", outcome: "no_response")

    assert_nil record.status_code
  end

  test "outcome defaults to ok and rejects anything outside the permitted set" do
    assert_equal "ok", CrawlRecord.create!(url: "https://example.com/x").outcome

    record = CrawlRecord.new(url: "https://example.com/y", outcome: "made up")

    assert_not record.valid?
    assert_includes record.errors[:outcome], "is not included in the list"
  end

  test "succeeded? distinguishes a stored page from an attempt that failed" do
    assert CrawlRecord.new(url: "https://example.com/x", outcome: "ok").succeeded?
    assert_not CrawlRecord.new(url: "https://example.com/x", outcome: "http_error").succeeded?
  end

  test "a url with no usable host is rejected rather than saved without a domain" do
    record = CrawlRecord.new(url: "not a url")

    assert_not record.valid?
    assert_includes record.errors[:domain], "must exist"
  end
end
