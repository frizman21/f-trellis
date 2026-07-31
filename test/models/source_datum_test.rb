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

  private

  def zipped(html)
    bytes = Zip::OutputStream.write_buffer do |zos|
      zos.put_next_entry("page.html")
      zos.write(html)
    end
    bytes.rewind

    SourceDatum.create!(source: sources(:one), content_type: "application/zip", data: bytes.read)
  end
end
