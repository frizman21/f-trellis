require "test_helper"

class ImportSourcesJobTest < ActiveJob::TestCase
  def import_for(text)
    SourceImport.create!(raw_urls: text)
  end

  def run_import(text)
    import = import_for(text)
    ImportSourcesJob.perform_now(import)
    import.reload
  end

  test "creates a source for every new url" do
    import = run_import(<<~URLS)
      https://bulk.test/one
      https://bulk.test/two
      https://bulk.test/three
    URLS

    assert_equal 3, import.submitted_count
    assert_equal 3, import.created_count
    assert_equal 0, import.existing_count
    assert_empty import.rejected_entries

    assert_equal 3, Source.where(url: [ "https://bulk.test/one",
                                        "https://bulk.test/two",
                                        "https://bulk.test/three" ]).count
  end

  test "imported sources are left in status new" do
    run_import("https://bulk.test/one\n")

    assert_equal "new", Source.find_by(url: "https://bulk.test/one").status
  end

  # The guard against someone later "tidying" this into a loop over
  # Source.for_url, which calls queue_initial_fetch and would silently turn a
  # paste of two thousand URLs into two thousand unpaced outbound requests.
  test "nothing is queued for fetching" do
    assert_no_enqueued_jobs only: FetchSourceJob do
      run_import("https://bulk.test/one\nhttps://bulk.test/two\n")
    end
  end

  test "a url already held is counted rather than duplicated" do
    Source.create!(url: "https://bulk.test/known")

    import = nil
    assert_difference -> { Source.count }, 1 do
      import = run_import("https://bulk.test/known\nhttps://bulk.test/fresh\n")
    end

    assert_equal 2, import.submitted_count
    assert_equal 1, import.created_count
    assert_equal 1, import.existing_count
  end

  # The counts have to keep adding up to submitted_count, which they only do if
  # the second line sees the row the first one just created.
  test "the same url twice in one paste creates one source" do
    import = nil
    assert_difference -> { Source.count }, 1 do
      import = run_import("https://bulk.test/dup\nhttps://bulk.test/dup\n")
    end

    assert_equal 2, import.submitted_count
    assert_equal 1, import.created_count
    assert_equal 1, import.existing_count
    assert_equal import.submitted_count,
                 import.created_count + import.existing_count + import.rejected_entries.size
  end

  test "blank and whitespace-only lines are ignored" do
    import = run_import("https://bulk.test/one\n\n   \n\nhttps://bulk.test/two\n")

    assert_equal 2, import.submitted_count
    assert_equal 2, import.created_count
  end

  # The same tolerance a single pasted URL already gets, which is the whole
  # reason this goes through Source.normalize_url rather than URI.parse.
  test "a spreadsheet paste is normalized the way a single pasted url is" do
    run_import(<<~URLS)
      bulk.test/no-scheme
        https://bulk.test/padded#{"  "}
      https://bulk.test/page#section
    URLS

    assert Source.exists?(url: "https://bulk.test/no-scheme"), "a missing scheme should be filled in"
    assert Source.exists?(url: "https://bulk.test/padded"), "surrounding space should be trimmed"
    assert Source.exists?(url: "https://bulk.test/page"), "a trailing fragment should be dropped"
  end

  # One bad line must not cost the paste — the alternative is asking somebody to
  # find the single malformed row in two thousand.
  test "an unusable line is rejected and the rest still import" do
    import = run_import(<<~URLS)
      https://bulk.test/before
      not a url at all
      https://bulk.test/after
    URLS

    assert_equal 3, import.submitted_count
    assert_equal 2, import.created_count
    assert_equal 1, import.rejected_entries.size

    rejection = import.rejected_entries.first
    assert_equal "not a url at all", rejection["value"]
    assert_equal "not a usable web address", rejection["reason"]

    assert Source.exists?(url: "https://bulk.test/before")
    assert Source.exists?(url: "https://bulk.test/after")
  end

  test "the import ends complete" do
    assert_equal "complete", run_import("https://bulk.test/one\n").status
  end

  # Without this an import that blew up part way sits at "running" forever,
  # which looks exactly like one still in progress.
  test "a job that fails marks the import failed and records why" do
    import = import_for("https://bulk.test/one\n")

    Source.singleton_class.class_eval do
      alias_method :create_without_stub!, :create!
      define_method(:create!) { |*| raise ActiveRecord::StatementInvalid, "database is down" }
    end

    begin
      assert_raises(ActiveRecord::StatementInvalid) { ImportSourcesJob.perform_now(import) }
    ensure
      Source.singleton_class.class_eval do
        remove_method :create!
        alias_method :create!, :create_without_stub!
        remove_method :create_without_stub!
      end
    end

    import.reload
    assert_equal "failed", import.status
    assert_match(/database is down/, import.error_message)
  end
end
