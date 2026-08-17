require "test_helper"

class SourceImportTest < ActiveSupport::TestCase
  test "a new import starts empty and unstarted" do
    import = SourceImport.create!(raw_urls: "https://a.test/one")

    assert_equal "new", import.status
    assert_equal 0, import.submitted_count
    assert_equal 0, import.created_count
    assert_equal 0, import.existing_count
    assert_equal [], import.rejected_entries
    assert_not import.finished?
  end

  test "raw_urls is required" do
    assert_not SourceImport.new(raw_urls: "").valid?
    assert_not SourceImport.new(raw_urls: nil).valid?
  end

  test "an unknown status is refused" do
    assert_not SourceImport.new(raw_urls: "https://a.test", status: "halfway").valid?
  end

  # One definition of "submitted", so the job and the count on screen can never
  # disagree about which lines counted.
  test "submitted_urls strips and drops the blank lines a spreadsheet brings along" do
    import = SourceImport.new(raw_urls: "  https://a.test/one \n\n\t\nhttps://a.test/two\n   \n")

    assert_equal [ "https://a.test/one", "https://a.test/two" ], import.submitted_urls
  end

  test "finished? covers both terminal states" do
    assert SourceImport.new(raw_urls: "x", status: "complete").finished?
    assert SourceImport.new(raw_urls: "x", status: "failed").finished?
    assert_not SourceImport.new(raw_urls: "x", status: "running").finished?
  end
end
