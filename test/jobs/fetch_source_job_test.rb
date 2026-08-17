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
end
