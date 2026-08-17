require "test_helper"
require "zip"
require "stringio"

class SourceDatumTest < ActiveSupport::TestCase
  test "#html decompresses the zip payload" do
    html = "<html><body>hi</body></html>"
    bytes = Zip::OutputStream.write_buffer do |zos|
      zos.put_next_entry("page.html")
      zos.write(html)
    end
    bytes.rewind

    source = sources(:one)
    datum = SourceDatum.create!(source: source, content_type: "application/zip", data: bytes.read)

    assert_equal html, datum.html
  end

  test "#html returns nil when data is blank" do
    source = sources(:one)
    datum = SourceDatum.new(source: source, content_type: "application/zip", data: nil)
    assert_nil datum.html
  end

  test "#text returns the page text without markup" do
    datum = zipped(<<~HTML)
      <html>
        <head><style>.a{}</style></head>
        <body><script>noise()</script><h1>Heading</h1><p>Paragraph.</p></body>
      </html>
    HTML

    text = datum.text

    assert_includes text, "Heading"
    assert_includes text, "Paragraph."
    assert_not_includes text, "<h1>"
    assert_not_includes text, "noise()"
  end

  test "#text returns an empty string when data is blank" do
    datum = SourceDatum.new(source: sources(:one), content_type: "application/zip", data: nil)

    assert_equal "", datum.text
  end

  test "#html handles an empty zip entry" do
    datum = zipped("")

    assert_equal "", datum.html
    assert_equal "", datum.text
  end

  test "#html is still available for link extraction after #text exists" do
    datum = zipped(%(<html><body><a href="https://example.com/x">x</a></body></html>))

    assert_includes datum.html, "<a href"
    assert_includes datum.extract_links.external + datum.extract_links.internal,
                    "https://example.com/x"
  end

  test "content_hash is set on create" do
    datum = zipped("<html><body><p>hashed</p></body></html>")

    assert_match(/\A[0-9a-f]{64}\z/, datum.content_hash)
  end

  test "identical text produces the same hash" do
    a = zipped("<html><body><p>same</p></body></html>")
    b = zipped("<html><body><p>same</p></body></html>")

    assert_equal a.content_hash, b.content_hash
  end

  test "different text produces different hashes" do
    a = zipped("<html><body><p>one</p></body></html>")
    b = zipped("<html><body><p>two</p></body></html>")

    assert_not_equal a.content_hash, b.content_hash
  end

  test "markup-only changes do not change the hash" do
    a = zipped("<html><body><p>Acme Corp</p></body></html>")
    b = zipped('<html><body><p class="promo" data-session="abc123">Acme Corp</p>' \
               "<script>track(1)</script></body></html>")

    assert_equal a.content_hash, b.content_hash,
      "hashing the extracted text should ignore markup and script churn"
  end

  test "content_hash is nil when there is no extractable text" do
    datum = zipped("<html><head><title>t</title></head></html>")

    assert_nil datum.content_hash
  end

  test "content_hash is nil when data is blank" do
    datum = SourceDatum.create!(source: sources(:one), content_type: "application/zip", data: nil)

    assert_nil datum.content_hash
  end

  # A PDF is stored exactly like a page — zipped bytes — and differs only by its
  # content_type. #text is the one dispatch point; every reader in the system
  # already goes through it, so none of them changes.
  test "#text extracts the text of a pdf payload" do
    datum = zipped_pdf("two_page_text.pdf")

    assert_includes datum.text, "Marriage Divorce Remarriage"
    assert_includes datum.text, "Second Page Heading"
  end

  # Specifically not mojibake, which is what running these bytes through
  # #html's force_encoding("UTF-8") would produce.
  test "#html is nil for a pdf payload rather than corrupted text" do
    datum = zipped_pdf("two_page_text.pdf")

    assert_nil datum.html
  end

  test "#extract_links on a pdf payload returns an empty result and does not raise" do
    datum = zipped_pdf("two_page_text.pdf")

    result = datum.extract_links

    assert_empty result.internal
    assert_empty result.external
    assert_empty result.excluded
  end

  test "#raw_bytes returns the stored document byte-identically" do
    datum = zipped_pdf("two_page_text.pdf")

    assert_equal pdf_fixture("two_page_text.pdf"), datum.raw_bytes
  end

  test "content_hash is set from a pdf's text and collapses for the same document" do
    a = zipped_pdf("two_page_text.pdf")
    b = zipped_pdf("two_page_text.pdf")

    assert a.content_hash.present?
    assert_equal a.content_hash, b.content_hash
  end

  # An empty text layer produces no hash, exactly as an HTML page with no
  # extractable text already does.
  test "content_hash is nil for a pdf with no text layer" do
    assert_nil zipped_pdf("image_only.pdf").content_hash
  end

  private

  def zipped(html)
    bytes = Zip::OutputStream.write_buffer do |zos|
      zos.put_next_entry("page.html")
      zos.write(html)
    end
    bytes.rewind

    SourceDatum.create!(source: sources(:one), content_type: "application/zip", data: bytes.read)
  end

  def pdf_fixture(name)
    File.binread(Rails.root.join("test/fixtures/files", name))
  end

  def zipped_pdf(name)
    bytes = Zip::OutputStream.write_buffer do |zos|
      zos.put_next_entry(name)
      zos.write(pdf_fixture(name))
    end
    bytes.rewind

    SourceDatum.create!(source: sources(:one), content_type: "application/pdf", data: bytes.read)
  end
end
