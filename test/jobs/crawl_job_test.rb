require "test_helper"
require "zip"
require "stringio"

class CrawlJobTest < ActiveJob::TestCase
  def zip(html, name = "page.html")
    buf = Zip::OutputStream.write_buffer do |zos|
      zos.put_next_entry(name)
      zos.write(html)
    end
    buf.rewind
    buf.read
  end

  def install_data(source, html)
    source.update_columns(status: "complete")
    SourceDatum.create!(source: source, content_type: "application/zip", data: zip(html))
  end

  def make_seed(url, html)
    source = Source.create!(url: url, description: "seed")
    install_data(source, html)
    source
  end

  def with_fake_fetcher(pages = {})
    test = self
    FetchSourceJob.define_singleton_method(:perform_now) do |source|
      html = pages[source.url]
      test.install_data(source, html) if html
    end
    yield
  ensure
    FetchSourceJob.singleton_class.send(:remove_method, :perform_now)
  end

  test "crawls seed only when depth is zero" do
    seed = make_seed("https://depth-zero.test/start", '<a href="/a">a</a>')

    with_fake_fetcher do
      assert_difference -> { CrawlRecord.count } => 1, -> { Source.count } => 0 do
        CrawlJob.perform_now(seed, crawl_type: "stay_in_domain", max_depth: 0)
      end
    end
  end

  test "stay-in-domain follows internal links and skips external" do
    seed = make_seed(
      "https://stay.test/start",
      '<a href="/internal">in</a><a href="https://other.test/elsewhere">out</a>'
    )

    with_fake_fetcher("https://stay.test/internal" => "<p>leaf</p>") do
      CrawlJob.perform_now(seed, crawl_type: "stay_in_domain", max_depth: 1)
    end

    assert Source.exists?(url: "https://stay.test/internal")
    assert_not Source.exists?(url: "https://other.test/elsewhere")
  end

  # A crawl fetches the children it creates itself, with perform_now. If the
  # initial fetch ever moves to an after_create callback, every crawled page
  # gets a second, racing download and this catches it.
  test "a crawl queues no fetch for the sources it creates" do
    seed = make_seed(
      "https://stay.test/start",
      '<a href="/internal">in</a>'
    )

    assert_no_enqueued_jobs only: FetchSourceJob do
      with_fake_fetcher("https://stay.test/internal" => "<p>leaf</p>") do
        CrawlJob.perform_now(seed, crawl_type: "stay_in_domain", max_depth: 1)
      end
    end

    assert Source.exists?(url: "https://stay.test/internal")
  end

  test "follow-external-links includes external urls" do
    seed = make_seed(
      "https://follow.test/start",
      '<a href="/internal">in</a><a href="https://elsewhere.test/page">out</a>'
    )

    with_fake_fetcher(
      "https://follow.test/internal" => "<p>leaf</p>",
      "https://elsewhere.test/page" => "<p>leaf</p>"
    ) do
      CrawlJob.perform_now(seed, crawl_type: "follow_external_links", max_depth: 1)
    end

    assert Source.exists?(url: "https://follow.test/internal")
    assert Source.exists?(url: "https://elsewhere.test/page")
  end

  test "deduplicates against existing sources without re-creating them" do
    seed = make_seed("https://dedup.test/start", '<a href="/known">known</a>')
    Source.create!(url: "https://dedup.test/known", description: "preexisting")

    with_fake_fetcher do
      assert_no_difference -> { Source.where(url: "https://dedup.test/known").count } do
        CrawlJob.perform_now(seed, crawl_type: "stay_in_domain", max_depth: 1)
      end
    end
  end

  test "logs a CrawlRecord for every page processed" do
    seed = make_seed("https://log.test/start", '<a href="/leaf">leaf</a>')

    with_fake_fetcher("https://log.test/leaf" => "<p>leaf</p>") do
      assert_difference -> { CrawlRecord.count }, 2 do
        CrawlJob.perform_now(seed, crawl_type: "stay_in_domain", max_depth: 1)
      end
    end
  end

  test "respects max_pages cap" do
    links = (1..10).map { |i| %(<a href="/p#{i}">#{i}</a>) }.join
    seed = make_seed("https://cap.test/start", links)
    pages = (1..10).each_with_object({}) { |i, h| h["https://cap.test/p#{i}"] = "<p>leaf</p>" }

    with_fake_fetcher(pages) do
      CrawlJob.perform_now(seed, crawl_type: "stay_in_domain", max_depth: 1, max_pages: 3)
    end

    crawled = CrawlRecord.where("url LIKE ?", "https://cap.test/%").count
    assert crawled <= 3, "expected at most 3 pages crawled, got #{crawled}"
  end

  test "sets parent_source to the page the link was found on" do
    seed = make_seed("https://parent.test/start", '<a href="/mid">mid</a>')

    with_fake_fetcher("https://parent.test/mid" => '<a href="/leaf">leaf</a>') do
      CrawlJob.perform_now(seed, crawl_type: "stay_in_domain", max_depth: 2)
    end

    mid  = Source.find_by(url: "https://parent.test/mid")
    leaf = Source.find_by(url: "https://parent.test/leaf")

    assert_equal seed, mid.parent_source
    assert_equal mid, leaf.parent_source, "leaf's parent should be mid, not the seed"
  end

  test "records a SourceLink edge for every link between known sources" do
    seed = make_seed("https://graph.test/start", '<a href="/a">a</a><a href="/b">b</a>')

    with_fake_fetcher(
      "https://graph.test/a" => "<p>leaf</p>",
      "https://graph.test/b" => "<p>leaf</p>"
    ) do
      CrawlJob.perform_now(seed, crawl_type: "stay_in_domain", max_depth: 1)
    end

    assert_equal %w[https://graph.test/a https://graph.test/b],
                 seed.reload.links_to.map(&:url).sort
  end

  test "records edges back to pages already seen in the crawl" do
    seed = make_seed("https://cycle.test/start", '<a href="/a">a</a>')

    with_fake_fetcher("https://cycle.test/a" => '<a href="https://cycle.test/start">back</a>') do
      CrawlJob.perform_now(seed, crawl_type: "stay_in_domain", max_depth: 2)
    end

    a = Source.find_by(url: "https://cycle.test/a")

    assert_includes seed.reload.links_to, a
    assert_includes a.reload.links_to, seed, "the link back to the seed should be recorded"
  end

  test "records an edge to a preexisting source without recreating it" do
    seed = make_seed("https://known.test/start", '<a href="/known">known</a>')
    known = Source.create!(url: "https://known.test/known", description: "preexisting")

    with_fake_fetcher do
      assert_no_difference -> { Source.count } do
        CrawlJob.perform_now(seed, crawl_type: "stay_in_domain", max_depth: 1)
      end
    end

    assert_includes seed.reload.links_to, known
    assert_nil known.reload.parent_source
  end

  test "re-crawling does not duplicate link edges" do
    seed = make_seed("https://rerun.test/start", '<a href="/a">a</a>')

    with_fake_fetcher("https://rerun.test/a" => "<p>leaf</p>") do
      CrawlJob.perform_now(seed, crawl_type: "stay_in_domain", max_depth: 1)

      assert_no_difference -> { SourceLink.count } do
        CrawlJob.perform_now(seed, crawl_type: "stay_in_domain", max_depth: 1)
      end
    end
  end

  test "excluded links are neither created nor followed" do
    SourceExclusion.create!(pattern: "https://excluded.test/item?id=*")

    seed = make_seed(
      "https://excluded.test/start",
      '<a href="/item?id=1">comments</a><a href="/keep">keep</a>'
    )

    with_fake_fetcher("https://excluded.test/keep" => '<a href="/item?id=2">more comments</a>') do
      CrawlJob.perform_now(seed, crawl_type: "stay_in_domain", max_depth: 2)
    end

    assert Source.exists?(url: "https://excluded.test/keep")
    assert_not Source.exists?(url: "https://excluded.test/item?id=1"),
      "an excluded link must not become a source"
    assert_not Source.exists?(url: "https://excluded.test/item?id=2"),
      "an excluded link must not be discovered a level deeper either"
    assert_not CrawlRecord.exists?(url: "https://excluded.test/item?id=1"),
      "an excluded link must not be fetched"
  end

  test "no link edge is recorded to an excluded URL that is already a source" do
    # The exclusion is added after the page already exists, which is the case
    # where the graph could still grow an edge to something we now refuse.
    known = Source.create!(url: "https://exclude-known.test/item?id=1")
    SourceExclusion.create!(pattern: "https://exclude-known.test/item?id=*")

    seed = make_seed("https://exclude-known.test/start", '<a href="/item?id=1">a</a>')

    with_fake_fetcher do
      assert_no_difference -> { SourceLink.count } do
        CrawlJob.perform_now(seed, crawl_type: "stay_in_domain", max_depth: 1)
      end
    end

    assert_not_includes seed.reload.links_to, known
  end

  test "raises on invalid crawl_type" do
    seed = make_seed("https://invalid.test/x", "")
    assert_raises ArgumentError do
      CrawlJob.perform_now(seed, crawl_type: "bogus", max_depth: 1)
    end
  end
end
