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
end
