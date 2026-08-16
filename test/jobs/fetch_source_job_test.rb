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
    assert_equal "application/zip", source.source_data.last.content_type
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
end
