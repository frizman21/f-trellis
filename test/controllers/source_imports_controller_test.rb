require "test_helper"

class SourceImportsControllerTest < ActionDispatch::IntegrationTest
  test "new renders the form" do
    get new_source_import_path

    assert_response :success
    assert_select "textarea[name=?]", "source_import[raw_urls]"
    # The decision a person needs to know before pasting two thousand URLs.
    assert_match(/Nothing is fetched/, response.body)
  end

  test "create stores the pasted text and enqueues one job" do
    urls = "https://bulk.test/one\nhttps://bulk.test/two\n"

    assert_difference -> { SourceImport.count }, 1 do
      assert_enqueued_jobs 1, only: ImportSourcesJob do
        post source_imports_path, params: { source_import: { raw_urls: urls } }
      end
    end

    import = SourceImport.order(:id).last
    assert_equal urls, import.raw_urls
    assert_redirected_to source_import_path(import)
  end

  # Two thousand inserts plus a Domain lookup each do not belong in a request,
  # and a timeout part way would leave a partial import with nothing recording
  # what happened.
  test "create does no importing in the request itself" do
    assert_no_difference -> { Source.count } do
      post source_imports_path,
           params: { source_import: { raw_urls: "https://bulk.test/one\n" } }
    end

    assert_equal "new", SourceImport.order(:id).last.status
  end

  test "create with an empty textarea re-renders rather than making an empty import" do
    assert_no_difference -> { SourceImport.count } do
      post source_imports_path, params: { source_import: { raw_urls: "  " } }
    end

    assert_response :unprocessable_entity
  end

  test "show renders the counts and one row per rejection" do
    import = SourceImport.create!(
      raw_urls: "https://bulk.test/one\nnot a url\n",
      status: "complete",
      submitted_count: 2,
      created_count: 1,
      existing_count: 0,
      rejected: [ { "value" => "not a url", "reason" => "not a usable web address" } ]
    )

    get source_import_path(import)

    assert_response :success
    assert_match(/Complete/, response.body)
    assert_match(/not a url/, response.body)
    assert_match(/not a usable web address/, response.body)
  end

  test "show says a failed import did not finish and why" do
    import = SourceImport.create!(raw_urls: "https://bulk.test/one",
                                  status: "failed",
                                  error_message: "ActiveRecord::StatementInvalid: database is down")

    get source_import_path(import)

    assert_response :success
    assert_match(/did not finish/, response.body)
    assert_match(/database is down/, response.body)
  end

  test "index lists imports newest first" do
    older = SourceImport.create!(raw_urls: "https://bulk.test/older")
    newer = SourceImport.create!(raw_urls: "https://bulk.test/newer")
    older.update_columns(created_at: 2.days.ago)

    get source_imports_path

    assert_response :success
    assert_operator response.body.index("/source_imports/#{newer.id}"),
                    :<,
                    response.body.index("/source_imports/#{older.id}")
  end

  test "the sources index offers a bulk add link" do
    get sources_path

    assert_response :success
    assert_select "a[href=?]", new_source_import_path
  end
end
