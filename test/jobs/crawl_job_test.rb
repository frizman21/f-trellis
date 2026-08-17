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

  # `failures` maps a URL to how the fetch fails: an Integer status code raises
  # SourceNotFetchable carrying it, :timeout raises something that never
  # produced a response at all.
  #
  # Stubs #fetch_html rather than the whole of .perform_now, so the real job
  # still runs: its guard, its status transitions, its SourceDatum write and —
  # the reason this matters — its FetchRecord write and outcome classification.
  # Replacing .perform_now would leave the crawl log tests below asserting
  # against the stub instead of against the code that writes the log.
  #
  # A URL in neither hash fetches as an empty page. Only the tests that supply
  # a page or a failure assert anything about that URL's record.
  #
  # Positional rather than keyword args: callers pass `pages` as a bare hash,
  # which Ruby would read as keywords if this method declared any.
  #
  # Every crawl in this file also runs through a pacer that records instead of
  # sleeping. Without it each page would really wait DEFAULT_CRAWL_DELAY_SECONDS
  # and the suite would take minutes — at which point it would stop being run.
  # Injected here rather than through a hook in CrawlJob, so production code
  # carries no seam that exists only for tests.
  attr_reader :slept

  def install_test_pacer
    @slept = []
    @pacer_clock = 0.0
    pacer = CrawlPacer.new(clock: -> { @pacer_clock },
                           sleeper: ->(seconds) { @slept << seconds; @pacer_clock += seconds })

    original = CrawlJob.method(:perform_now)
    CrawlJob.define_singleton_method(:perform_now) do |seed, **kwargs|
      original.call(seed, **{ pacer: pacer }.merge(kwargs))
    end
  end

  def remove_test_pacer
    CrawlJob.singleton_class.send(:remove_method, :perform_now)
  end

  # Without this, every test host resolves to nothing, robots.txt comes back
  # unreachable, and RFC 9309 says an unreadable robots.txt puts the site off
  # limits — so every crawl test would be disallowed. `robots` maps a host to a
  # robots.txt body; a host not named permits everything.
  attr_reader :robots_calls

  # Aliased rather than replaced: policy_for is defined directly on
  # RobotsFetcher's singleton class, so define_singleton_method would overwrite
  # it and removing the stub would leave the class with no method at all.
  def install_robots(robots)
    @robots_calls = 0
    test = self

    RobotsFetcher.singleton_class.class_eval do
      alias_method :policy_for_without_stub, :policy_for
      define_method(:policy_for) do |domain, agent: CrawlerIdentity.product_token|
        test.count_robots_call
        body = robots[domain&.host]
        body.nil? ? RobotsPolicy.allow_all : RobotsPolicy.parse(body, agent: agent)
      end
    end
  end

  def count_robots_call
    @robots_calls += 1
  end

  def remove_robots
    RobotsFetcher.singleton_class.class_eval do
      remove_method :policy_for
      alias_method :policy_for, :policy_for_without_stub
      remove_method :policy_for_without_stub
    end
  end

  def with_fake_fetcher(pages = {}, failures = {}, robots = {})
    install_test_pacer
    install_robots(robots)
    FetchSourceJob.class_eval do
      alias_method :fetch_html_without_stub, :fetch_html
      define_method(:fetch_html) do |url|
        failure = failures[url]
        raise Net::ReadTimeout if failure == :timeout

        if failure
          raise FetchSourceJob::SourceNotFetchable.new("refused #{url}", status_code: failure)
        end

        FetchSourceJob::Fetched.new(body: pages.fetch(url, ""), final_url: url,
                                    content_type: "text/html", status_code: 200)
      end
    end
    yield
  ensure
    FetchSourceJob.class_eval do
      remove_method :fetch_html
      alias_method :fetch_html, :fetch_html_without_stub
      remove_method :fetch_html_without_stub
    end
    remove_test_pacer
    remove_robots
  end

  test "crawls seed only when depth is zero" do
    seed = make_seed("https://depth-zero.test/start", '<a href="/a">a</a>')

    with_fake_fetcher do
      assert_difference -> { FetchRecord.count } => 1, -> { Source.count } => 0 do
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

  test "logs a FetchRecord for every page processed" do
    seed = make_seed("https://log.test/start", '<a href="/leaf">leaf</a>')

    with_fake_fetcher("https://log.test/leaf" => "<p>leaf</p>") do
      assert_difference -> { FetchRecord.count }, 2 do
        CrawlJob.perform_now(seed, crawl_type: "stay_in_domain", max_depth: 1)
      end
    end
  end

  # --- page-level directives -------------------------------------------------

  test "a nofollowed link is not fetched and no source is created for it" do
    seed = make_seed("https://nofollowed.test/start",
                     '<a href="/paid" rel="sponsored">ad</a><a href="/real">real</a>')

    with_fake_fetcher("https://nofollowed.test/real" => "<p>real</p>") do
      CrawlJob.perform_now(seed, crawl_type: "stay_in_domain", max_depth: 1)
    end

    assert_nil Source.find_by(url: "https://nofollowed.test/paid")
    assert Source.find_by(url: "https://nofollowed.test/real").source_data.any?
  end

  test "a nofollowed url that already exists gains no new edge" do
    seed = make_seed("https://nofollow-edge.test/start", '<a href="/known" rel="nofollow">known</a>')
    known = Source.create!(url: "https://nofollow-edge.test/known")

    with_fake_fetcher do
      assert_no_difference -> { SourceLink.count } do
        CrawlJob.perform_now(seed, crawl_type: "stay_in_domain", max_depth: 1)
      end
    end

    assert_not SourceLink.exists?(from_source: seed, to_source: known)
  end

  # noindex is not nofollow: the page is still crawled and its links followed.
  test "a noindex page is still crawled and its links still followed" do
    seed = make_seed("https://noindexed.test/start",
                     '<html><head><meta name="robots" content="noindex"></head>' \
                     '<body><a href="/leaf">leaf</a></body></html>')

    with_fake_fetcher("https://noindexed.test/leaf" => "<p>leaf</p>") do
      CrawlJob.perform_now(seed, crawl_type: "stay_in_domain", max_depth: 1)
    end

    assert Source.find_by(url: "https://noindexed.test/leaf").source_data.any?
  end

  # --- robots.txt ------------------------------------------------------------

  test "a disallowed url is neither fetched nor turned into a source" do
    seed = make_seed("https://robotted.test/start", '<a href="/private/x">no</a><a href="/ok">yes</a>')
    robots = { "robotted.test" => "User-agent: *\nDisallow: /private\n" }

    with_fake_fetcher({ "https://robotted.test/ok" => "<p>fine</p>" }, {}, robots) do
      CrawlJob.perform_now(seed, crawl_type: "stay_in_domain", max_depth: 1)
    end

    blocked = Source.find_by(url: "https://robotted.test/private/x")

    assert_empty blocked.source_data, "a disallowed page must not be fetched"
    assert Source.find_by(url: "https://robotted.test/ok").source_data.any?
  end

  test "a disallowed page is logged as disallowed rather than as a failure" do
    seed = make_seed("https://logged.test/start", '<a href="/private/x">no</a>')
    robots = { "logged.test" => "User-agent: *\nDisallow: /private\n" }

    with_fake_fetcher({}, {}, robots) do
      CrawlJob.perform_now(seed, crawl_type: "stay_in_domain", max_depth: 1)
    end

    record = FetchRecord.find_by(url: "https://logged.test/private/x")

    assert_equal "disallowed", record.outcome
    assert_nil record.status_code
  end

  test "a disallowed seed is not fetched and the crawl does not raise" do
    seed = Source.create!(url: "https://blocked.test/start")
    robots = { "blocked.test" => "User-agent: *\nDisallow: /\n" }

    with_fake_fetcher({ "https://blocked.test/start" => "<p>never</p>" }, {}, robots) do
      CrawlJob.perform_now(seed, crawl_type: "stay_in_domain", max_depth: 1)
    end

    assert_empty seed.reload.source_data
    assert_equal "disallowed", FetchRecord.find_by(url: "https://blocked.test/start").outcome
  end

  test "a site whose robots.txt names us is held to our own rules" do
    seed = make_seed("https://named.test/start", '<a href="/admin">a</a><a href="/open">b</a>')
    robots = {
      "named.test" => "User-agent: *\nDisallow: /\n\nUser-agent: f-agents\nDisallow: /admin\n"
    }

    with_fake_fetcher({ "https://named.test/open" => "<p>open</p>" }, {}, robots) do
      CrawlJob.perform_now(seed, crawl_type: "stay_in_domain", max_depth: 1)
    end

    assert_empty Source.find_by(url: "https://named.test/admin").source_data
    assert Source.find_by(url: "https://named.test/open").source_data.any?
  end

  test "robots.txt is consulted once per host, not once per page" do
    seed = make_seed("https://once-robots.test/start",
                     '<a href="/a">a</a><a href="/b">b</a><a href="/c">c</a>')

    with_fake_fetcher({ "https://once-robots.test/a" => "<p>a</p>",
                        "https://once-robots.test/b" => "<p>b</p>",
                        "https://once-robots.test/c" => "<p>c</p>" }) do
      CrawlJob.perform_now(seed, crawl_type: "stay_in_domain", max_depth: 1)
    end

    assert_equal 1, robots_calls, "four pages on one host should ask robots.txt once"
  end

  test "a delay the site asks for is used when no operator setting overrides it" do
    domain = Domain.create!(host: "asked.test", robots_crawl_delay_seconds: 6)

    assert_equal 6, CrawlJob.delay_for(domain)

    domain.update!(min_crawl_delay_seconds: 2)

    assert_equal 2, CrawlJob.delay_for(domain), "an operator's setting outranks the site's request"
  end

  # --- pacing ----------------------------------------------------------------

  test "a two-page crawl of one host waits once, for the domain's delay" do
    seed = make_seed("https://paced.test/start", '<a href="/leaf">leaf</a>')
    seed.domain.update!(min_crawl_delay_seconds: 4)

    with_fake_fetcher("https://paced.test/leaf" => "<p>leaf</p>") do
      CrawlJob.perform_now(seed, crawl_type: "stay_in_domain", max_depth: 1)
    end

    assert_equal [ 4.0 ], slept
  end

  test "a one-page crawl never waits" do
    seed = make_seed("https://single.test/start", "<p>nothing linked</p>")
    seed.domain.update!(min_crawl_delay_seconds: 4)

    with_fake_fetcher do
      CrawlJob.perform_now(seed, crawl_type: "stay_in_domain", max_depth: 0)
    end

    assert_empty slept
  end

  test "a crawl across two hosts does not pace one against the other" do
    seed = make_seed("https://hostA.test/start", '<a href="https://hostB.test/page">out</a>')
    seed.domain.update!(min_crawl_delay_seconds: 4)

    with_fake_fetcher("https://hostB.test/page" => "<p>elsewhere</p>") do
      CrawlJob.perform_now(seed, crawl_type: "follow_external_links", max_depth: 1)
    end

    assert_empty slept
  end

  # The promise the domain form has always made and never kept.
  test "a domain with no delay set uses the crawler's default" do
    seed = make_seed("https://defaulted.test/start", '<a href="/leaf">leaf</a>')

    assert_nil seed.domain.min_crawl_delay_seconds

    with_fake_fetcher("https://defaulted.test/leaf" => "<p>leaf</p>") do
      CrawlJob.perform_now(seed, crawl_type: "stay_in_domain", max_depth: 1)
    end

    assert_equal [ CrawlJob::DEFAULT_CRAWL_DELAY_SECONDS.to_f ], slept
  end

  test "an explicit delay is preferred over the default" do
    assert_equal 9, CrawlJob.delay_for(Domain.new(host: "x.test", min_crawl_delay_seconds: 9))
    assert_equal CrawlJob::DEFAULT_CRAWL_DELAY_SECONDS, CrawlJob.delay_for(Domain.new(host: "x.test"))
    assert_equal CrawlJob::DEFAULT_CRAWL_DELAY_SECONDS, CrawlJob.delay_for(nil)
  end

  # Zero is a real setting: an operator saying "this site is ours, go fast".
  test "a delay of zero disables waiting" do
    seed = make_seed("https://fast.test/start", '<a href="/leaf">leaf</a>')
    seed.domain.update!(min_crawl_delay_seconds: 0)

    with_fake_fetcher("https://fast.test/leaf" => "<p>leaf</p>") do
      CrawlJob.perform_now(seed, crawl_type: "stay_in_domain", max_depth: 1)
    end

    assert_empty slept
  end

  test "edges name the snapshot the links were read out of" do
    seed = make_seed("https://prov.test/start", '<a href="/leaf">leaf</a>')

    with_fake_fetcher("https://prov.test/leaf" => "<p>leaf</p>") do
      CrawlJob.perform_now(seed, crawl_type: "stay_in_domain", max_depth: 1)
    end

    link = SourceLink.find_by(from_source: seed)

    assert_equal seed.latest_datum, link.source_datum
  end

  test "re-crawling a re-fetched page leaves the original snapshot on the edge" do
    seed = make_seed("https://stable.test/start", '<a href="/leaf">leaf</a>')

    with_fake_fetcher("https://stable.test/leaf" => "<p>leaf</p>") do
      CrawlJob.perform_now(seed, crawl_type: "stay_in_domain", max_depth: 1)
    end

    first_datum = seed.latest_datum

    # A second fetch appends a snapshot; the crawl then reads links from it.
    install_data(seed, '<a href="/leaf">leaf</a>')

    with_fake_fetcher("https://stable.test/leaf" => "<p>leaf</p>") do
      CrawlJob.perform_now(seed, crawl_type: "stay_in_domain", max_depth: 1)
    end

    assert_not_equal first_datum, seed.reload.latest_datum, "the page was re-fetched"
    assert_equal first_datum, SourceLink.find_by(from_source: seed).source_datum
  end

  # --- the crawl log ---------------------------------------------------------

  test "records written during a crawl say a crawl started them" do
    seed = make_seed("https://trigger.test/start", '<a href="/leaf">leaf</a>')

    with_fake_fetcher("https://trigger.test/leaf" => "<p>leaf</p>") do
      CrawlJob.perform_now(seed, crawl_type: "stay_in_domain", max_depth: 1)
    end

    assert_equal [ "crawl" ], FetchRecord.where("url LIKE ?", "https://trigger.test/%").distinct.pluck(:trigger)
  end

  test "a page fetched successfully records its status" do
    seed = make_seed("https://status.test/start", '<a href="/leaf">leaf</a>')

    with_fake_fetcher("https://status.test/leaf" => "<p>leaf</p>") do
      CrawlJob.perform_now(seed, crawl_type: "stay_in_domain", max_depth: 1)
    end

    record = FetchRecord.find_by(url: "https://status.test/leaf")

    assert_equal 200, record.status_code
    assert_equal "ok", record.outcome
  end

  # The behaviour that did not exist: a failed page left no record at all,
  # because the write sat after the fetch inside the same rescue.
  test "a page whose fetch fails still leaves a record" do
    seed = make_seed("https://failing.test/start", '<a href="/gone">gone</a>')

    with_fake_fetcher({}, "https://failing.test/gone" => 404) do
      assert_difference -> { FetchRecord.count }, 2 do
        CrawlJob.perform_now(seed, crawl_type: "stay_in_domain", max_depth: 1)
      end
    end

    record = FetchRecord.find_by(url: "https://failing.test/gone")

    assert_equal 404, record.status_code
    assert_equal "http_error", record.outcome
  end

  test "a page we reached but refused is recorded as unusable, not as an http error" do
    seed = make_seed("https://refused.test/start", '<a href="/doc.pdf">pdf</a>')

    with_fake_fetcher({}, "https://refused.test/doc.pdf" => 200) do
      CrawlJob.perform_now(seed, crawl_type: "stay_in_domain", max_depth: 1)
    end

    record = FetchRecord.find_by(url: "https://refused.test/doc.pdf")

    assert_equal 200, record.status_code, "the server answered fine; we declined what it sent"
    assert_equal "unusable", record.outcome
  end

  test "a request that produced no response at all records a null status" do
    seed = make_seed("https://timeout.test/start", '<a href="/slow">slow</a>')

    with_fake_fetcher({}, "https://timeout.test/slow" => :timeout) do
      CrawlJob.perform_now(seed, crawl_type: "stay_in_domain", max_depth: 1)
    end

    record = FetchRecord.find_by(url: "https://timeout.test/slow")

    assert_nil record.status_code
    assert_equal "no_response", record.outcome
  end

  test "a page already held is recorded as skipped rather than as a fetch" do
    seed = make_seed("https://held.test/start", "<p>already here</p>")

    with_fake_fetcher do
      CrawlJob.perform_now(seed, crawl_type: "stay_in_domain", max_depth: 0)
    end

    record = FetchRecord.find_by(url: "https://held.test/start")

    assert_equal "skipped", record.outcome
    assert_nil record.status_code
  end

  test "a failed page produces exactly one record, not zero and not two" do
    seed = make_seed("https://once.test/start", '<a href="/bad">bad</a>')

    with_fake_fetcher({}, "https://once.test/bad" => 500) do
      CrawlJob.perform_now(seed, crawl_type: "stay_in_domain", max_depth: 1)
    end

    assert_equal 1, FetchRecord.where(url: "https://once.test/bad").count
  end

  # The existing exclusion guard, kept: the new write path must not start
  # logging pages that were never attempted.
  test "an excluded url is still never recorded" do
    SourceExclusion.create!(pattern: "https://logskip.test/private*", is_enabled: true)
    seed = make_seed("https://logskip.test/start", '<a href="/private/x">no</a>')

    with_fake_fetcher do
      CrawlJob.perform_now(seed, crawl_type: "stay_in_domain", max_depth: 1)
    end

    assert_not FetchRecord.exists?(url: "https://logskip.test/private/x")
  end

  test "crawl records are attributable to the host they were fetched from" do
    seed = make_seed("https://attributed.test/start", '<a href="/leaf">leaf</a>')

    with_fake_fetcher("https://attributed.test/leaf" => "<p>leaf</p>") do
      CrawlJob.perform_now(seed, crawl_type: "stay_in_domain", max_depth: 1)
    end

    hosts = FetchRecord.where(url: [ "https://attributed.test/start", "https://attributed.test/leaf" ])
                       .map { |record| record.domain.host }

    assert_equal [ "attributed.test" ], hosts.uniq
  end

  test "a crawl across two hosts writes records against both domains" do
    seed = make_seed("https://first.test/start", '<a href="https://second.test/page">out</a>')

    with_fake_fetcher("https://second.test/page" => "<p>elsewhere</p>") do
      CrawlJob.perform_now(seed, crawl_type: "follow_external_links", max_depth: 1)
    end

    assert_equal "first.test", FetchRecord.find_by(url: "https://first.test/start").domain.host
    assert_equal "second.test", FetchRecord.find_by(url: "https://second.test/page").domain.host
  end

  # A crawl of a real site hits things it cannot read — a linked PDF, a dead
  # page. One of them must not end the crawl.
  test "a page the fetcher refuses does not stop the crawl" do
    seed = make_seed("https://mixed.test/start",
                     '<a href="/doc.pdf">datasheet</a><a href="/next">next</a>')

    with_fake_fetcher({ "https://mixed.test/next" => "<p>reached</p>" },
                      { "https://mixed.test/doc.pdf" => 200 }) do
      CrawlJob.perform_now(seed, crawl_type: "stay_in_domain", max_depth: 1)
    end

    refused = Source.find_by(url: "https://mixed.test/doc.pdf")
    reached = Source.find_by(url: "https://mixed.test/next")

    assert_not_nil refused, "the refused page is still recorded as a source"
    assert_empty refused.source_data, "nothing is stored for a page that could not be read"
    assert reached.source_data.any?, "the crawl continued past the refused page"
  end

  test "respects max_pages cap" do
    links = (1..10).map { |i| %(<a href="/p#{i}">#{i}</a>) }.join
    seed = make_seed("https://cap.test/start", links)
    pages = (1..10).each_with_object({}) { |i, h| h["https://cap.test/p#{i}"] = "<p>leaf</p>" }

    with_fake_fetcher(pages) do
      CrawlJob.perform_now(seed, crawl_type: "stay_in_domain", max_depth: 1, max_pages: 3)
    end

    crawled = FetchRecord.where("url LIKE ?", "https://cap.test/%").count
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
    assert_not FetchRecord.exists?(url: "https://excluded.test/item?id=1"),
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
