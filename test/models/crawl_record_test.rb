require "test_helper"

class CrawlRecordTest < ActiveSupport::TestCase
  test "requires a url" do
    record = CrawlRecord.new
    assert_not record.valid?
    assert_includes record.errors[:url], "can't be blank"
  end

  test "stores the crawl timestamp via created_at" do
    record = CrawlRecord.create!(url: "https://example.com/x")
    assert_not_nil record.created_at
  end
end
