require "test_helper"

class FetchSourceJobTest < ActiveJob::TestCase
  # with_fake_http lives in test_helper — it stubs the single outbound request
  # rather than the whole of #fetch_html, so headers and status codes stay
  # observable here and in every card that follows.

  test "fetches a source in status new" do
    source = Source.create!(url: "https://fetch.test/page")

    with_fake_http do
      assert_difference -> { SourceDatum.count }, 1 do
        FetchSourceJob.perform_now(source)
      end
    end

    assert_equal "complete", source.reload.status
    assert_equal "text/html", source.source_data.last.content_type
  end

  test "skips a source that is not new unless forced" do
    source = Source.create!(url: "https://skip.test/page")
    source.update!(status: "complete")

    with_fake_http do
      assert_no_difference -> { SourceDatum.count } do
        FetchSourceJob.perform_now(source)
      end
    end
  end

  test "force refetches a source that is already complete" do
    source = Source.create!(url: "https://force.test/page")
    source.update!(status: "complete")

    with_fake_http do
      assert_difference -> { SourceDatum.count }, 1 do
        FetchSourceJob.perform_now(source, force: true)
      end
    end

    assert_equal "complete", source.reload.status
  end

  test "force refetches a source that previously failed" do
    source = Source.create!(url: "https://retry.test/page")
    source.update!(status: "failed")

    with_fake_http do
      FetchSourceJob.perform_now(source, force: true)
    end

    assert_equal "complete", source.reload.status
  end

  test "refetching adds a payload rather than replacing the previous one" do
    source = Source.create!(url: "https://history.test/page")

    with_fake_http do
      FetchSourceJob.perform_now(source)
      FetchSourceJob.perform_now(source, force: true)
    end

    assert_equal 2, source.reload.source_data.count
  end

  test "the zipped payload round-trips back to the fetched html" do
    source = Source.create!(url: "https://zip.test/page")

    with_fake_http("<html><body><p>round trip</p></body></html>") do
      FetchSourceJob.perform_now(source)
    end

    assert_equal "<html><body><p>round trip</p></body></html>",
                 source.reload.source_data.last.html
  end

  test "the outgoing request carries the configured crawler identity" do
    source = Source.create!(url: "https://agent.test/page")

    with_fake_http do |requests|
      FetchSourceJob.perform_now(source)

      assert_equal 1, requests.size
      assert_equal CrawlerIdentity.user_agent, requests.first[:headers]["User-Agent"]
    end
  end

  # The literal this replaced. Named so a revert is loud rather than silent.
  test "the outgoing request no longer sends the hardcoded f-dod agent" do
    source = Source.create!(url: "https://agent.test/legacy")

    with_fake_http do |requests|
      FetchSourceJob.perform_now(source)

      assert_not_equal "f-dod/1.0", requests.first[:headers]["User-Agent"]
      assert_includes requests.first[:headers]["User-Agent"], "f-agents"
    end
  end

  test "a non-2xx response fails the source" do
    source = Source.create!(url: "https://gone.test/page")

    with_fake_http(code: "404") do
      assert_no_difference -> { SourceDatum.count } do
        assert_raises(FetchSourceJob::SourceNotFetchable) { FetchSourceJob.perform_now(source) }
      end
    end

    assert_equal "failed", source.reload.status
  end

  # --- redirects -------------------------------------------------------------

  def redirect_to(location, code: "301")
    { code: code, body: "", headers: { "Location" => location } }
  end

  def ok(body = "<html><body>moved here</body></html>")
    { code: "200", body: body, headers: { "Content-Type" => "text/html" } }
  end

  test "a 301 to an absolute URL fetches the target and stores its body" do
    source = Source.create!(url: "http://redirect.test/page")

    with_fake_http(responses: [ redirect_to("https://redirect.test/page"), ok ]) do |requests|
      FetchSourceJob.perform_now(source)

      assert_equal 2, requests.size
      assert_equal "https://redirect.test/page", requests.last[:uri].to_s
    end

    assert_equal "complete", source.reload.status
    assert_equal "https://redirect.test/page", source.resolved_url
    assert_includes source.source_data.last.html, "moved here"
  end

  test "a relative Location resolves against the current URL" do
    source = Source.create!(url: "https://relative.test/a/b")

    with_fake_http(responses: [ redirect_to("/c/d"), ok ]) do |requests|
      FetchSourceJob.perform_now(source)

      assert_equal "https://relative.test/c/d", requests.last[:uri].to_s
    end

    assert_equal "https://relative.test/c/d", source.reload.resolved_url
  end

  test "307 and 308 are followed as well as 301 and 302" do
    %w[302 303 307 308].each do |code|
      source = Source.create!(url: "https://code#{code}.test/page")

      with_fake_http(responses: [ redirect_to("https://code#{code}.test/final", code: code), ok ]) do
        FetchSourceJob.perform_now(source)
      end

      assert_equal "complete", source.reload.status, "expected #{code} to be followed"
    end
  end

  test "a chain within the limit succeeds" do
    source = Source.create!(url: "https://chain.test/0")

    responses = 3.times.map { |i| redirect_to("https://chain.test/#{i + 1}") } + [ ok ]

    with_fake_http(responses: responses) do
      FetchSourceJob.perform_now(source)
    end

    assert_equal "complete", source.reload.status
    assert_equal "https://chain.test/3", source.resolved_url
  end

  test "a chain beyond the limit fails rather than following forever" do
    source = Source.create!(url: "https://long.test/0")

    responses = 7.times.map { |i| redirect_to("https://long.test/#{i + 1}") }

    with_fake_http(responses: responses) do
      error = assert_raises(FetchSourceJob::SourceNotFetchable) { FetchSourceJob.perform_now(source) }
      assert_match(/too many redirects/, error.message)
    end

    assert_equal "failed", source.reload.status
  end

  test "a redirect back to a URL already visited fails as a loop" do
    source = Source.create!(url: "https://loop.test/a")

    with_fake_http(responses: [ redirect_to("https://loop.test/b"), redirect_to("https://loop.test/a") ]) do
      error = assert_raises(FetchSourceJob::SourceNotFetchable) { FetchSourceJob.perform_now(source) }
      assert_match(/redirect loop/, error.message)
    end
  end

  test "a redirect with no Location header fails with a stated reason" do
    source = Source.create!(url: "https://nowhere.test/page")

    with_fake_http(code: "302") do
      error = assert_raises(FetchSourceJob::SourceNotFetchable) { FetchSourceJob.perform_now(source) }
      assert_match(/no Location/, error.message)
    end
  end

  test "a redirect to a non-http scheme fails without requesting it" do
    source = Source.create!(url: "https://scheme.test/page")

    with_fake_http(responses: [ redirect_to("ftp://scheme.test/file"), ok ]) do |requests|
      assert_raises(FetchSourceJob::SourceNotFetchable) { FetchSourceJob.perform_now(source) }

      assert_equal 1, requests.size, "the ftp target must not be requested"
    end
  end

  test "a redirect to an excluded URL fails without requesting it" do
    SourceExclusion.create!(pattern: "https://excluded.test/*", is_enabled: true)
    source = Source.create!(url: "https://ok.test/page")

    with_fake_http(responses: [ redirect_to("https://excluded.test/trap"), ok ]) do |requests|
      error = assert_raises(FetchSourceJob::SourceNotFetchable) { FetchSourceJob.perform_now(source) }

      assert_match(/excluded/, error.message)
      assert_equal 1, requests.size
    end
  end

  test "resolved_url stays nil when nothing redirected" do
    source = Source.create!(url: "https://direct.test/page")

    with_fake_http do
      FetchSourceJob.perform_now(source)
    end

    assert_nil source.reload.resolved_url
  end

  # --- conditional requests --------------------------------------------------

  test "a source with no validators sends no conditional headers" do
    source = Source.create!(url: "https://fresh.test/page")

    with_fake_http do |requests|
      FetchSourceJob.perform_now(source)

      assert_nil requests.first[:headers]["If-None-Match"]
      assert_nil requests.first[:headers]["If-Modified-Since"]
    end
  end

  test "an etag is sent back as If-None-Match" do
    source = Source.create!(url: "https://etagged.test/page", etag: 'W/"abc"')

    with_fake_http do |requests|
      FetchSourceJob.perform_now(source)

      assert_equal 'W/"abc"', requests.first[:headers]["If-None-Match"]
    end
  end

  test "a last-modified is sent back as an HTTP-date" do
    modified = Time.zone.parse("2026-01-02 03:04:05 UTC")
    source = Source.create!(url: "https://dated-page.test/page", last_modified_at: modified)

    with_fake_http do |requests|
      FetchSourceJob.perform_now(source)

      assert_equal modified.httpdate, requests.first[:headers]["If-Modified-Since"]
    end
  end

  test "a 200 records the validators the response carried" do
    source = Source.create!(url: "https://records.test/page")
    headers = { "Content-Type" => "text/html", "ETag" => '"xyz"',
                "Last-Modified" => "Wed, 21 Oct 2026 07:28:00 GMT" }

    with_fake_http(headers: headers) do
      FetchSourceJob.perform_now(source)
    end

    assert_equal '"xyz"', source.reload.etag
    assert_equal Time.utc(2026, 10, 21, 7, 28, 0), source.last_modified_at
  end

  test "a response that stops sending an ETag clears the stored one" do
    source = Source.create!(url: "https://dropped.test/page", etag: '"old"')

    with_fake_http do
      FetchSourceJob.perform_now(source, force: true)
    end

    assert_nil source.reload.etag
  end

  # The core case. 304 is not a Net::HTTPSuccess, so without the classification
  # change this would fail every unchanged page.
  test "a 304 stores no new datum and leaves the source complete" do
    source = Source.create!(url: "https://unchanged.test/page", etag: '"same"')

    with_fake_http { FetchSourceJob.perform_now(source, force: true) }

    assert_equal 1, source.reload.source_data.count
    original = source.source_data.last

    with_fake_http(code: "304") do
      assert_no_difference -> { SourceDatum.count } do
        FetchSourceJob.perform_now(source, force: false)
      end
    end

    assert_equal "complete", source.reload.status
    assert_equal original, source.latest_datum, "the datum already held is still current"
  end

  test "a forced refetch sends no conditional headers, so the button always returns content" do
    source = Source.create!(url: "https://forced.test/page", etag: '"same"',
                            last_modified_at: 1.day.ago)

    with_fake_http do |requests|
      FetchSourceJob.perform_now(source, force: true)

      assert_nil requests.first[:headers]["If-None-Match"]
      assert_nil requests.first[:headers]["If-Modified-Since"]
    end
  end

  test "a malformed Last-Modified is ignored rather than raising" do
    source = Source.create!(url: "https://badly-dated.test/page")

    with_fake_http(headers: { "Content-Type" => "text/html", "Last-Modified" => "whenever" }) do
      FetchSourceJob.perform_now(source)
    end

    assert_equal "complete", source.reload.status
    assert_nil source.last_modified_at
  end

  # Proves the relaxed status check did not widen into accepting everything.
  test "a 404 still fails once 304 is a success" do
    source = Source.create!(url: "https://still-gone.test/page")

    with_fake_http(code: "404") do
      assert_raises(FetchSourceJob::SourceNotFetchable) { FetchSourceJob.perform_now(source) }
    end

    assert_equal "failed", source.reload.status
  end

  test "validators are only sent on the first hop of a redirect chain" do
    source = Source.create!(url: "https://hopped.test/page", etag: '"first"')

    with_fake_http(responses: [ redirect_to("https://hopped.test/final"), ok ]) do |requests|
      FetchSourceJob.perform_now(source)

      assert_equal '"first"', requests.first[:headers]["If-None-Match"]
      assert_nil requests.last[:headers]["If-None-Match"],
                 "an ETag for one URL would provoke a spurious 304 from another"
    end
  end

  # --- backoff and retry -----------------------------------------------------

  test "a 429 is retried and can succeed" do
    source = Source.create!(url: "https://limited.test/page")

    with_fake_http(responses: [ { code: "429", body: "" }, ok ]) do |requests|
      FetchSourceJob.perform_now(source)

      assert_equal 2, requests.size
    end

    assert_equal "complete", source.reload.status
    assert_equal 1, source.source_data.count, "a retry must not store the page twice"
  end

  test "a 503 is retried and a 404 is not" do
    transient = Source.create!(url: "https://blip.test/page")

    with_fake_http(responses: [ { code: "503", body: "" }, ok ]) do
      FetchSourceJob.perform_now(transient)
    end

    assert_equal "complete", transient.reload.status

    permanent = Source.create!(url: "https://gone-for-good.test/page")

    with_fake_http(code: "404") do |requests|
      assert_raises(FetchSourceJob::SourceNotFetchable) { FetchSourceJob.perform_now(permanent) }

      assert_equal 1, requests.size, "a definite answer is not worth asking for twice"
    end
  end

  test "a timeout is retried" do
    source = Source.create!(url: "https://slow.test/page")

    with_fake_http(responses: [ { raise: Net::ReadTimeout.new }, ok ]) do |requests|
      FetchSourceJob.perform_now(source)

      assert_equal 2, requests.size
    end

    assert_equal "complete", source.reload.status
  end

  test "retries are bounded and the source then fails" do
    source = Source.create!(url: "https://always-down.test/page")

    with_fake_http(code: "503") do |requests|
      assert_raises(FetchSourceJob::SourceTemporarilyUnavailable) { FetchSourceJob.perform_now(source) }

      assert_equal FetchSourceJob::MAX_ATTEMPTS, requests.size
    end

    assert_equal "failed", source.reload.status
  end

  test "the backoff grows between attempts" do
    source = Source.create!(url: "https://backoff.test/page")

    with_fake_http(code: "503") do
      assert_raises(FetchSourceJob::SourceTemporarilyUnavailable) { FetchSourceJob.perform_now(source) }
    end

    assert_equal [ 1, 2, 4 ], fake_http_slept
  end

  # An instruction, not a suggestion.
  test "Retry-After in seconds overrides our own backoff" do
    source = Source.create!(url: "https://polite.test/page")

    with_fake_http(responses: [ { code: "429", body: "", headers: { "Retry-After" => "42" } }, ok ]) do
      FetchSourceJob.perform_now(source)
    end

    assert_equal [ 42 ], fake_http_slept
  end

  test "Retry-After as an HTTP-date is converted to a delay from now" do
    source = Source.create!(url: "https://dated.test/page")
    header = 30.seconds.from_now.httpdate

    with_fake_http(responses: [ { code: "503", body: "", headers: { "Retry-After" => header } }, ok ]) do
      FetchSourceJob.perform_now(source)
    end

    assert_in_delta 30, fake_http_slept.first, 2
  end

  test "a Retry-After beyond the ceiling gives up rather than parking a worker" do
    source = Source.create!(url: "https://very-slow.test/page")
    header = (FetchSourceJob::MAX_RETRY_AFTER + 1.hour).to_i.to_s

    with_fake_http(code: "503", headers: { "Retry-After" => header }) do |requests|
      assert_raises(FetchSourceJob::SourceTemporarilyUnavailable) { FetchSourceJob.perform_now(source) }

      assert_equal 1, requests.size
    end

    assert_empty fake_http_slept
    assert_equal "failed", source.reload.status
  end

  test "a malformed Retry-After is ignored rather than raising" do
    source = Source.create!(url: "https://garbled.test/page")

    with_fake_http(responses: [ { code: "503", body: "", headers: { "Retry-After" => "soon-ish" } }, ok ]) do
      FetchSourceJob.perform_now(source)
    end

    assert_equal "complete", source.reload.status
    assert_equal [ 1 ], fake_http_slept
  end

  # The regression this card is most likely to introduce.
  test "an intermediate retry does not mark the source failed" do
    source = Source.create!(url: "https://recovers.test/page")

    with_fake_http(responses: [ { code: "503", body: "" }, ok ]) do
      FetchSourceJob.perform_now(source)
    end

    assert_equal "complete", source.reload.status
  end

  # --- stuck sources ---------------------------------------------------------

  test "a source left in_work by a dead worker becomes fetchable again" do
    source = Source.create!(url: "https://stuck.test/page")
    source.update!(status: "in_work")
    source.update_columns(updated_at: 2.hours.ago)

    with_fake_http do
      assert_difference -> { SourceDatum.count }, 1 do
        FetchSourceJob.perform_now(source)
      end
    end

    assert_equal "complete", source.reload.status
  end

  test "a source in_work recently is left alone, since it is probably running" do
    source = Source.create!(url: "https://running.test/page")
    source.update!(status: "in_work")

    with_fake_http do
      assert_no_difference -> { SourceDatum.count } do
        FetchSourceJob.perform_now(source)
      end
    end
  end

  # --- noindex ---------------------------------------------------------------

  test "a page with no directives is indexable" do
    source = Source.create!(url: "https://plain.test/page")

    with_fake_http do
      FetchSourceJob.perform_now(source)
    end

    assert_not source.reload.is_noindex
  end

  test "a meta robots noindex marks the source" do
    source = Source.create!(url: "https://meta-noindex.test/page")
    html = '<html><head><meta name="robots" content="noindex"></head><body>x</body></html>'

    with_fake_http(html) do
      FetchSourceJob.perform_now(source)
    end

    assert source.reload.is_noindex
  end

  # The piece most likely to be dropped: the header is only knowable at fetch
  # time, since the stored payload is the body alone.
  test "an X-Robots-Tag header marks the source even with no meta tag" do
    source = Source.create!(url: "https://header-noindex.test/page")

    with_fake_http(headers: { "Content-Type" => "text/html", "X-Robots-Tag" => "noindex" }) do
      FetchSourceJob.perform_now(source)
    end

    assert source.reload.is_noindex
  end

  test "an X-Robots-Tag of nofollow does not mark the page noindex" do
    source = Source.create!(url: "https://header-nofollow.test/page")

    with_fake_http(headers: { "Content-Type" => "text/html", "X-Robots-Tag" => "nofollow" }) do
      FetchSourceJob.perform_now(source)
    end

    assert_not source.reload.is_noindex
  end

  test "re-fetching a page that dropped its noindex clears the flag" do
    source = Source.create!(url: "https://changed.test/page")
    html = '<html><head><meta name="robots" content="noindex"></head><body>x</body></html>'

    with_fake_http(html) { FetchSourceJob.perform_now(source) }

    assert source.reload.is_noindex

    with_fake_http("<html><body>now indexable</body></html>") do
      FetchSourceJob.perform_now(source, force: true)
    end

    assert_not source.reload.is_noindex
  end

  # --- content types ---------------------------------------------------------

  def fetch_with_type(url, content_type, body: "<html><body>hi</body></html>")
    source = Source.create!(url: url)
    headers = content_type.nil? ? {} : { "Content-Type" => content_type }

    with_fake_http(body, headers: headers) do
      yield source
    end

    source
  end

  test "html content types are accepted" do
    [ "text/html", "text/html; charset=utf-8", "TEXT/HTML", "application/xhtml+xml" ].each_with_index do |type, i|
      source = fetch_with_type("https://type#{i}.test/page", type) do |s|
        FetchSourceJob.perform_now(s)
      end

      assert_equal "complete", source.reload.status, "expected #{type} to be accepted"
    end
  end

  test "a response with no Content-Type is accepted" do
    source = fetch_with_type("https://notype.test/page", nil) do |s|
      FetchSourceJob.perform_now(s)
    end

    assert_equal "complete", source.reload.status
    assert_equal "text/html", source.source_data.last.content_type
  end

  test "non-html content types are refused and store nothing" do
    %w[application/pdf image/png application/json].each_with_index do |type, i|
      source = Source.create!(url: "https://bad#{i}.test/file")

      with_fake_http("%PDF-1.4 binary", headers: { "Content-Type" => type }) do
        assert_no_difference -> { SourceDatum.count } do
          error = assert_raises(FetchSourceJob::SourceNotFetchable) { FetchSourceJob.perform_now(source) }
          assert_match(/unsupported content type: #{Regexp.escape(type)}/, error.message)
        end
      end

      assert_equal "failed", source.reload.status
    end
  end

  # The parameter is stripped before comparing, and the stored type is the bare
  # media type rather than the header verbatim.
  test "the stored content type describes the payload, not the zip container" do
    source = fetch_with_type("https://stored.test/page", "text/html; charset=utf-8") do |s|
      FetchSourceJob.perform_now(s)
    end

    assert_equal "text/html", source.source_data.last.content_type
  end

  test "a body declared as ISO-8859-1 round-trips as valid UTF-8" do
    latin1 = "<html><body><p>caf\xE9</p></body></html>".dup.force_encoding("ASCII-8BIT")
    source = Source.create!(url: "https://latin1.test/page")

    with_fake_http(latin1, headers: { "Content-Type" => "text/html; charset=ISO-8859-1" }) do
      FetchSourceJob.perform_now(source)
    end

    html = source.reload.source_data.last.html

    assert html.valid_encoding?, "stored html should be valid UTF-8"
    assert_includes html, "café"
  end

  test "bytes that are invalid for the declared charset are replaced rather than raising" do
    broken = "<html><body>\xFF\xFEbad</body></html>".dup.force_encoding("ASCII-8BIT")
    source = Source.create!(url: "https://broken.test/page")

    with_fake_http(broken, headers: { "Content-Type" => "text/html; charset=UTF-8" }) do
      FetchSourceJob.perform_now(source)
    end

    assert_equal "complete", source.reload.status
    assert source.source_data.last.html.valid_encoding?
  end

  test "an unknown charset does not fail the fetch" do
    source = fetch_with_type("https://charset.test/page", "text/html; charset=not-a-charset") do |s|
      FetchSourceJob.perform_now(s)
    end

    assert_equal "complete", source.reload.status
  end

  test "an unsupported scheme fails without making a request" do
    # Saved past validation because a non-http URL cannot be created normally —
    # the point is that the job refuses it rather than requesting it.
    source = Source.new(url: "ftp://files.test/page", domain: domains(:example_com))
    source.save!(validate: false)

    with_fake_http do |requests|
      assert_raises(FetchSourceJob::SourceNotFetchable) { FetchSourceJob.perform_now(source) }

      assert_empty requests
    end
  end

  # Every fetch leaves a record — that is the whole point of moving the write
  # here from CrawlJob, so these assert the guarantee rather than the mechanism.

  test "a successful fetch writes exactly one record carrying the status the server sent" do
    source = Source.create!(url: "https://logged.test/page")

    with_fake_http do
      assert_difference -> { FetchRecord.count }, 1 do
        FetchSourceJob.perform_now(source, trigger: "crawl")
      end
    end

    record = FetchRecord.order(:id).last
    assert_equal "https://logged.test/page", record.url
    assert_equal "ok", record.outcome
    assert_equal 200, record.status_code
    assert_equal "crawl", record.trigger
    assert_equal "logged.test", record.domain.host
  end

  test "a fetch the guard declines is recorded as skipped with no status" do
    source = Source.create!(url: "https://declined.test/page")
    source.update!(status: "complete")

    with_fake_http do
      assert_difference -> { FetchRecord.count }, 1 do
        FetchSourceJob.perform_now(source)
      end
    end

    record = FetchRecord.order(:id).last
    assert_equal "skipped", record.outcome
    assert_nil record.status_code
  end

  test "an error status is recorded as http_error with that status" do
    source = Source.create!(url: "https://gone.test/page")

    with_fake_http(code: "404") do
      assert_difference -> { FetchRecord.count }, 1 do
        assert_raises(FetchSourceJob::SourceNotFetchable) { FetchSourceJob.perform_now(source) }
      end
    end

    record = FetchRecord.order(:id).last
    assert_equal "http_error", record.outcome
    assert_equal 404, record.status_code
  end

  # The outcome cannot be derived from the status alone: this one answered 200.
  test "a refused content type is recorded as unusable even though the server said 200" do
    source = Source.create!(url: "https://brochure.test/doc.pdf")

    with_fake_http("%PDF-1.4", headers: { "Content-Type" => "application/pdf" }) do
      assert_difference -> { FetchRecord.count }, 1 do
        assert_raises(FetchSourceJob::SourceNotFetchable) { FetchSourceJob.perform_now(source) }
      end
    end

    record = FetchRecord.order(:id).last
    assert_equal "unusable", record.outcome
    assert_equal 200, record.status_code
  end

  test "a request that got no answer at all is recorded as no_response" do
    source = Source.create!(url: "https://silent.test/page")

    with_fake_http(responses: [ { raise: Timeout::Error.new("execution expired") } ]) do
      assert_difference -> { FetchRecord.count }, 1 do
        assert_raises(Timeout::Error) { FetchSourceJob.perform_now(source) }
      end
    end

    record = FetchRecord.order(:id).last
    assert_equal "no_response", record.outcome
    assert_nil record.status_code
  end

  test "the manual and initial triggers reach the record" do
    manual  = Source.create!(url: "https://byhand.test/page")
    initial = Source.create!(url: "https://oncreate.test/page")

    with_fake_http do
      FetchSourceJob.perform_now(manual, trigger: "manual")
      FetchSourceJob.perform_now(initial, trigger: "initial")
    end

    assert_equal "manual",  FetchRecord.find_by(url: "https://byhand.test/page").trigger
    assert_equal "initial", FetchRecord.find_by(url: "https://oncreate.test/page").trigger
  end

  # The log must never be the reason a fetch fails.
  test "a record that cannot be written does not fail the fetch" do
    source = Source.create!(url: "https://logbroken.test/page")

    FetchRecord.singleton_class.class_eval do
      alias_method :create_without_stub!, :create!
      define_method(:create!) { |*| raise ActiveRecord::StatementInvalid, "log is down" }
    end

    begin
      with_fake_http do
        assert_difference -> { SourceDatum.count }, 1 do
          FetchSourceJob.perform_now(source)
        end
      end
    ensure
      FetchRecord.singleton_class.class_eval do
        remove_method :create!
        alias_method :create!, :create_without_stub!
        remove_method :create_without_stub!
      end
    end

    assert_equal "complete", source.reload.status
  end

  # The unit tests around TruncateSqlLogs drive the subscriber directly, so they
  # cannot catch the initializer failing to load or the prepend landing on the
  # wrong class. This is the whole path: fetch, zip, insert, log.
  test "storing a payload does not write the payload to the sql log" do
    source = Source.create!(url: "https://sqllog.test/page")
    # Incompressible on purpose. A repetitive body zips down below the cap and
    # the test would pass without the subscriber doing anything.
    body   = "<html><body><p>#{SecureRandom.hex(50_000)}</p></body></html>"

    log = capture_sql_log do
      without_prepared_statements do
        with_fake_http(body) { FetchSourceJob.perform_now(source) }
      end
    end

    insert = log.lines.find { |line| line.include?('INSERT INTO "source_data"') }

    # Without this the test could pass vacuously: with prepared statements on
    # the statement is short whatever the subscriber does, and the configuration
    # that actually produced the defect would go unexercised.
    assert insert, "expected the insert to be interpolated into the logged statement"
    assert_includes insert, "characters elided"

    oversized = log.lines.select { |line| line.length > 4_096 }
    assert_empty oversized, "expected no log line to carry the payload"

    # Truncated in the log, not on the way to the database.
    assert_equal body, source.reload.source_data.last.html
  end

  private

  def capture_sql_log
    io           = StringIO.new
    logger       = ActiveSupport::Logger.new(io)
    logger.level = :debug

    original  = ActiveRecord::Base.logger
    colorize  = ActiveSupport::LogSubscriber.colorize_logging
    ActiveRecord::Base.logger = logger
    ActiveSupport::LogSubscriber.colorize_logging = false

    yield
    io.string
  ensure
    ActiveRecord::Base.logger = original
    ActiveSupport::LogSubscriber.colorize_logging = colorize
  end

  # Test runs with prepared statements on; development does not, because
  # `query_log_tags_enabled` turns them off. The defect only appears with them
  # off, so the connection is flipped for the duration and restored after.
  def without_prepared_statements
    connection = ActiveRecord::Base.lease_connection
    original   = connection.prepared_statements
    connection.instance_variable_set(:@prepared_statements, false)

    yield
  ensure
    connection.instance_variable_set(:@prepared_statements, original)
  end
end
