require "test_helper"
require "zip"

class SourceDataControllerTest < ActionDispatch::IntegrationTest
  setup do
    @source = sources(:one)
  end

  # The zip is storage, not identity. Once content_type describes the page, a
  # download hands back the page rather than the container it was stored in.
  test "download returns the page itself for a datum typed as html" do
    datum = zipped_datum("<html><body><p>downloaded</p></body></html>", content_type: "text/html")

    get download_source_datum_path(datum)

    assert_response :success
    assert_equal "text/html", response.media_type
    assert_equal "<html><body><p>downloaded</p></body></html>", response.body
    assert_match(/\.html"?$/, response.headers["Content-Disposition"].split("filename=").last.delete('"'))
  end

  # Rows written before that change cannot be backfilled — the original header
  # was never captured — so they are still served as the zip they are.
  test "download still returns the archive for a legacy zip-typed datum" do
    datum = zipped_datum("<html><body><p>legacy</p></body></html>")

    get download_source_datum_path(datum)

    assert_response :success
    assert_equal "application/zip", response.media_type
    assert_equal datum.data, response.body
  end

  test "extract_links lists internal and external links from the zipped payload" do
    datum = zipped_datum(<<~HTML)
      <html><body>
        <a href="/about">relative internal</a>
        <a href="#{@source.url}deep/page">absolute internal</a>
        <a href="https://elsewhere.example.org/page">external</a>
        <a href="#skip">fragment only</a>
        <a href="mailto:x@example.com">mailto</a>
      </body></html>
    HTML

    post extract_links_source_datum_path(datum)

    assert_response :success
    assert_match(/about/, response.body)
    assert_match(/elsewhere\.example\.org/, response.body)
    assert_no_match(/mailto:/, response.body)
  end

  test "extract_links creates a source for each new internal and external link" do
    datum = zipped_datum(<<~HTML)
      <html><body>
        <a href="/about">internal</a>
        <a href="https://elsewhere.example.org/page">external</a>
      </body></html>
    HTML

    assert_difference "Source.count", 2 do
      post extract_links_source_datum_path(datum)
    end

    assert_response :success

    internal = Source.find_by(url: "https://example.com/about")
    external = Source.find_by(url: "https://elsewhere.example.org/page")

    assert internal, "expected a source for the internal link"
    assert external, "expected a source for the external link"
    assert_equal "new", internal.status
    assert_equal "Discovered by link extraction from #{@source.url}", internal.description
    assert_equal "elsewhere.example.org", external.domain.host
    assert_equal @source, internal.parent_source
    assert_equal @source, external.parent_source
  end

  # One click here can create hundreds of rows. None of them is a page somebody
  # asked for, so none of them downloads — the guard against this moving to an
  # after_create callback.
  test "extract_links queues no fetch for the sources it creates" do
    datum = zipped_datum(<<~HTML)
      <html><body>
        <a href="/about">internal</a>
        <a href="https://elsewhere.example.org/page">external</a>
      </body></html>
    HTML

    assert_no_enqueued_jobs only: FetchSourceJob do
      post extract_links_source_datum_path(datum)
    end

    assert_response :success
  end

  test "extract_links records a link edge for every link it resolves" do
    datum = zipped_datum(<<~HTML)
      <html><body>
        <a href="/about">new</a>
        <a href="https://elsewhere.example.org/page">new external</a>
      </body></html>
    HTML

    assert_difference "SourceLink.count", 2 do
      post extract_links_source_datum_path(datum)
    end

    assert_equal %w[https://elsewhere.example.org/page https://example.com/about],
                 @source.reload.links_to.map(&:url).sort
  end

  test "extract_links records edges to sources that already existed" do
    known = Source.create!(url: "https://example.com/about", description: "Already known")
    datum = zipped_datum(%(<html><body><a href="/about">known</a></body></html>))

    assert_difference "SourceLink.count", 1 do
      assert_no_difference "Source.count" do
        post extract_links_source_datum_path(datum)
      end
    end

    assert_includes @source.reload.links_to, known
    assert_includes known.reload.linked_from, @source
    assert_nil known.parent_source, "an existing source keeps its original parentage"
  end

  test "extract_links is idempotent for link edges when run twice" do
    datum = zipped_datum(%(<html><body><a href="/about">a</a></body></html>))

    post extract_links_source_datum_path(datum)

    assert_no_difference [ "SourceLink.count", "Source.count" ] do
      post extract_links_source_datum_path(datum)
    end
  end

  test "extract_links skips links that are already sources" do
    Source.create!(url: "https://example.com/about", description: "Already known")
    datum = zipped_datum(<<~HTML)
      <html><body>
        <a href="/about">already a source</a>
        <a href="/contact">new</a>
      </body></html>
    HTML

    assert_difference "Source.count", 1 do
      post extract_links_source_datum_path(datum)
    end

    assert_response :success
    assert_equal 1, Source.where(url: "https://example.com/about").count
    assert_match(/already known/i, response.body)
  end

  test "extract_links does not create a source or edge pointing back at itself" do
    datum = zipped_datum(%(<html><body><a href="#{@source.url}">self</a></body></html>))

    assert_no_difference [ "Source.count", "SourceLink.count" ] do
      post extract_links_source_datum_path(datum)
    end

    assert_response :success
  end

  test "extract_links reports when the payload has no links" do
    datum = zipped_datum("<html><body><p>Nothing to follow.</p></body></html>")

    assert_no_difference "Source.count" do
      post extract_links_source_datum_path(datum)
    end

    assert_response :success
    assert_match(/No links found/, response.body)
  end

  test "extract_links degrades gracefully on a payload that is not a valid zip" do
    datum = SourceDatum.create!(source: @source, content_type: "application/zip", data: "not a zip at all")

    post extract_links_source_datum_path(datum)

    assert_response :success
    assert_match(/No links found/, response.body)
  end

  test "extract_links renders an error and creates nothing when extraction raises" do
    # Source#assign_domain_from_url swallows a malformed URL, so such a source
    # can persist — but LinkExtractor parses the base URL unguarded and raises.
    @source = Source.create!(url: "http://[malformed", description: "Malformed URL",
                             domain: domains(:example_com))
    datum = zipped_datum(%(<html><body><a href="/x">x</a></body></html>))

    assert_no_difference "Source.count" do
      post extract_links_source_datum_path(datum)
    end

    assert_response :success
    assert_match(/Could not unzip/, response.body)
  end

  test "extract_links creates nothing for an excluded link and reports it" do
    SourceExclusion.create!(pattern: "https://elsewhere.example.org/item?id=*")

    datum = zipped_datum(<<~HTML)
      <html><body>
        <a href="/about">kept</a>
        <a href="https://elsewhere.example.org/item?id=7">excluded</a>
      </body></html>
    HTML

    assert_difference "Source.count", 1 do
      post extract_links_source_datum_path(datum)
    end

    assert_response :success
    assert_not Source.exists?(url: "https://elsewhere.example.org/item?id=7")
    assert_match(/Excluded \(1\)/, response.body)
  end

  test "extract_links records no edge to an excluded link that is already a source" do
    Source.create!(url: "https://elsewhere.example.org/item?id=7")
    SourceExclusion.create!(pattern: "https://elsewhere.example.org/item?id=*")

    datum = zipped_datum(<<~HTML)
      <html><body>
        <a href="https://elsewhere.example.org/item?id=7">excluded</a>
      </body></html>
    HTML

    assert_no_difference "SourceLink.count" do
      post extract_links_source_datum_path(datum)
    end

    assert_response :success
  end

  test "source show page offers an Extract links button for each datum" do
    datum = zipped_datum("<html><body></body></html>")

    get source_path(@source)

    assert_response :success
    assert_select "form[action=?][method=?]", extract_links_source_datum_path(datum), "post"
  end

  private

  def zipped_datum(html, content_type: "application/zip")
    buffer = Zip::OutputStream.write_buffer do |zos|
      zos.put_next_entry("page.html")
      zos.write(html)
    end
    buffer.rewind

    SourceDatum.create!(source: @source, content_type: content_type, data: buffer.read)
  end
end
