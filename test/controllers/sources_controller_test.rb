require "test_helper"

class SourcesControllerTest < ActionDispatch::IntegrationTest
  test "index renders and paginates without raising NoMethodError" do
    get sources_path
    assert_response :success
  end

  test "relation responds to #page (Kaminari wired in)" do
    assert Source.all.respond_to?(:page),
      "expected ActiveRecord::Relation to respond to #page — is kaminari loaded?"
  end

  test "show page renders the crawl form" do
    get source_path(sources(:one))
    assert_response :success
    assert_select "form[action=?]", crawl_source_path(sources(:one))
    assert_select "select[name=?]", "crawl_type"
    assert_select "input[name=?]", "max_depth"
    assert_select "input[name=?]", "max_pages"
  end

  test "crawl enqueues a CrawlJob with parsed params" do
    source = sources(:one)
    assert_enqueued_with(job: CrawlJob) do
      post crawl_source_path(source),
           params: { crawl_type: "stay_in_domain", max_depth: "2", max_pages: "100" }
    end
    assert_redirected_to source_path(source)
  end

  test "crawl rejects unknown crawl_type without enqueueing" do
    source = sources(:one)
    assert_no_enqueued_jobs only: CrawlJob do
      post crawl_source_path(source), params: { crawl_type: "bogus", max_depth: "1" }
    end
    assert_redirected_to source_path(source)
    follow_redirect!
    assert_match(/Invalid crawl type/, response.body)
  end
end
