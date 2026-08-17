require "test_helper"

class DomainTest < ActiveSupport::TestCase
  test "requires host" do
    domain = Domain.new
    assert_not domain.valid?
    assert_includes domain.errors[:host], "can't be blank"
  end

  test "host is unique case-insensitively" do
    Domain.create!(host: "unique.test")
    dup = Domain.new(host: "UNIQUE.test")
    assert_not dup.valid?
    assert_includes dup.errors[:host], "has already been taken"
  end

  test "downcases host on save" do
    domain = Domain.create!(host: "MixedCase.Test")
    assert_equal "mixedcase.test", domain.host
  end

  test "min_crawl_delay_seconds may be nil" do
    domain = Domain.new(host: "example.org")
    assert domain.valid?
  end

  test "min_crawl_delay_seconds rejects negatives" do
    domain = Domain.new(host: "example.org", min_crawl_delay_seconds: -1)
    assert_not domain.valid?
  end

  test "destroy is blocked while sources still reference the domain" do
    domain = domains(:example_com)
    assert_not domain.destroy
    assert_includes domain.errors[:base].join, "Cannot delete"
  end

  test "for_url returns the domain already known for a host" do
    assert_equal domains(:example_com), Domain.for_url("https://example.com/some/page")
  end

  test "for_url creates a domain the first time a host is seen" do
    assert_difference -> { Domain.count }, 1 do
      assert_equal "brand-new.test", Domain.for_url("https://brand-new.test/page").host
    end
  end

  test "for_url downcases the host" do
    assert_equal "example.com", Domain.for_url("HTTPS://Example.COM/page").host
  end

  test "for_url returns nil rather than raising on an unusable url" do
    assert_nil Domain.for_url("not a url")
    assert_nil Domain.for_url("")
    assert_nil Domain.for_url(nil)
  end

  # A log is about the domain and means nothing without it, unlike a source.
  test "destroying a domain takes its crawl records with it" do
    domain = Domain.create!(host: "logs-only.test")
    FetchRecord.create!(url: "https://logs-only.test/a", domain: domain)

    assert_difference -> { FetchRecord.count }, -1 do
      assert domain.destroy
    end
  end
end
