require "test_helper"

class FetchSourceJobTest < ActiveJob::TestCase
  # Stub the network so these tests only exercise the status guard.
  def with_fake_http(body = "<html><body>hi</body></html>")
    FetchSourceJob.class_eval do
      alias_method :fetch_html_without_stub, :fetch_html
      define_method(:fetch_html) { |_url| body }
    end
    yield
  ensure
    FetchSourceJob.class_eval do
      remove_method :fetch_html
      alias_method :fetch_html, :fetch_html_without_stub
      remove_method :fetch_html_without_stub
    end
  end

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
end
