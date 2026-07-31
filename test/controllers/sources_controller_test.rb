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

  test "show page names the parent source and links to both link pages with counts" do
    parent = sources(:two)
    source = Source.create!(url: "https://example.com/middle", parent_source: parent)
    downstream = Source.create!(url: "https://example.com/downstream")

    SourceLink.record(from: source, to: downstream)
    SourceLink.record(from: parent, to: source)

    get source_path(source)

    assert_response :success
    assert_select "dt", text: "Parent source"
    assert_select "a[href=?]", source_path(parent)
    assert_select "a[href=?]", links_from_source_path(source), text: /Links from this source \(1\)/
    assert_select "a[href=?]", links_to_source_path(source), text: /Links to this source \(1\)/
  end

  test "show page renders for a source with no parent and no links" do
    source = sources(:one)

    get source_path(source)

    assert_response :success
    assert_select "a[href=?]", links_from_source_path(source), text: /Links from this source \(0\)/
    assert_select "a[href=?]", links_to_source_path(source), text: /Links to this source \(0\)/
  end

  test "links_from page lists the sources this one links out to" do
    source = sources(:one)
    downstream = Source.create!(url: "https://example.com/downstream")
    SourceLink.record(from: source, to: downstream)

    get links_from_source_path(source)

    assert_response :success
    assert_select "a[href=?]", source_path(downstream)
    assert_select "a[href=?]", source_path(source), text: "Back to source"
  end

  test "links_to page lists the sources linking here" do
    source = sources(:one)
    upstream = Source.create!(url: "https://example.com/upstream")
    SourceLink.record(from: upstream, to: source)

    get links_to_source_path(source)

    assert_response :success
    assert_select "a[href=?]", source_path(upstream)
  end

  test "link pages are directional" do
    source = sources(:one)
    downstream = Source.create!(url: "https://example.com/downstream")
    SourceLink.record(from: source, to: downstream)

    get links_to_source_path(source)

    assert_response :success
    assert_select "a[href=?]", source_path(downstream), count: 0
    assert_match(/No other source is known to link here/, response.body)
  end

  test "link pages render and paginate when empty" do
    source = sources(:one)

    get links_from_source_path(source)
    assert_response :success
    assert_match(/No outbound links recorded/, response.body)

    get links_to_source_path(source)
    assert_response :success
    assert_match(/No other source is known to link here/, response.body)
  end

  test "links_from paginates" do
    source = sources(:one)
    60.times { |i| SourceLink.record(from: source, to: Source.create!(url: "https://example.com/p#{i}")) }

    get links_from_source_path(source)

    assert_response :success
    assert_select "tbody tr", 50
    assert_match(/Showing 50 of 60/, response.body)
  end

  test "show page always offers a fetch button" do
    new_source = sources(:one)
    done_source = Source.create!(url: "https://example.com/done")
    done_source.update!(status: "complete")

    get source_path(new_source)
    assert_select "form[action=?]", fetch_source_path(new_source)
    assert_select "button", text: "Fetch content"

    get source_path(done_source)
    assert_select "form[action=?]", fetch_source_path(done_source)
    assert_select "button", text: "Re-fetch content"
  end

  test "fetch enqueues a forced FetchSourceJob for a source in status new" do
    source = sources(:one)

    assert_enqueued_with(job: FetchSourceJob, args: [ source, { force: true } ]) do
      post fetch_source_path(source)
    end

    assert_redirected_to source_path(source)
    follow_redirect!
    assert_match(/Fetch queued/, response.body)
  end

  test "fetch enqueues for a source that is already complete" do
    source = Source.create!(url: "https://example.com/already-done")
    source.update!(status: "complete")

    assert_enqueued_with(job: FetchSourceJob, args: [ source, { force: true } ]) do
      post fetch_source_path(source)
    end

    follow_redirect!
    assert_match(/Re-fetch queued/, response.body)
    assert_match(/was complete/, response.body)
  end

  test "fetch enqueues for a source that previously failed" do
    source = Source.create!(url: "https://example.com/broken")
    source.update!(status: "failed")

    assert_enqueued_jobs 1, only: FetchSourceJob do
      post fetch_source_path(source)
    end
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
