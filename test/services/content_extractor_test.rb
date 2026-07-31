require "test_helper"

class ContentExtractorTest < ActiveSupport::TestCase
  test "returns the visible text of the body" do
    text = ContentExtractor.call("<html><body><h1>Title</h1><p>Body copy.</p></body></html>")

    assert_includes text, "Title"
    assert_includes text, "Body copy."
  end

  test "drops the markup itself" do
    text = ContentExtractor.call('<html><body><div class="x"><a href="/y">Link</a></div></body></html>')

    assert_equal "Link", text
    assert_not_includes text, "<"
    assert_not_includes text, "href"
  end

  test "removes script, style and noscript content" do
    html = <<~HTML
      <html>
        <head><style>.a { color: red }</style></head>
        <body>
          <script>var secret = "do not send";</script>
          <noscript>Enable JavaScript</noscript>
          <p>Keep this.</p>
        </body>
      </html>
    HTML

    text = ContentExtractor.call(html)

    assert_includes text, "Keep this."
    assert_not_includes text, "do not send"
    assert_not_includes text, "color: red"
    assert_not_includes text, "Enable JavaScript"
  end

  test "keeps adjacent table cells from running together" do
    html = "<html><body><table><tr><td>Acme Corp</td><td>25016</td></tr>" \
           "<tr><td>Beta Inc</td><td>15005</td></tr></table></body></html>"

    text = ContentExtractor.call(html)

    assert_not_includes text, "Acme Corp25016"
    assert_not_includes text, "2501Beta"
    assert_includes text, "Acme Corp"
    assert_includes text, "25016"
    assert_includes text, "Beta Inc"
  end

  test "keeps block elements on separate lines" do
    text = ContentExtractor.call("<html><body><p>First</p><p>Second</p></body></html>")

    assert_equal %w[First Second], text.split("\n")
  end

  test "does not insert space inside inline markup, matching how a browser renders it" do
    text = ContentExtractor.call("<html><body><p>Ac<b>me</b> Corp</p></body></html>")

    assert_equal "Acme Corp", text
  end

  test "collapses runs of whitespace and blank lines" do
    text = ContentExtractor.call("<html><body><p>a   \t  b</p>\n\n\n<p>c</p></body></html>")

    assert_not_includes text, "  "
    assert_not_includes text, "\n\n"
  end

  test "returns an empty string for blank input" do
    assert_equal "", ContentExtractor.call("")
    assert_equal "", ContentExtractor.call("   ")
    assert_equal "", ContentExtractor.call(nil)
  end

  test "returns an empty string for a document with no body" do
    assert_equal "", ContentExtractor.call("<html><head><title>t</title></head></html>")
  end

  test "handles non-ascii content" do
    text = ContentExtractor.call("<html><body><p>Ariane — Évry</p></body></html>")

    assert_includes text, "Ariane — Évry"
    assert_equal Encoding::UTF_8, text.encoding
  end

  test "strips a realistic page down to its content" do
    rows = 200.times.map { |i| "<tr><td>Exhibitor #{i}</td><td>#{i}</td></tr>" }.join
    html = <<~HTML
      <html><head><style>#{'.pad{}' * 500}</style></head>
      <body><script>#{'noise();' * 500}</script><table>#{rows}</table></body></html>
    HTML

    text = ContentExtractor.call(html)

    assert_includes text, "Exhibitor 0"
    assert_includes text, "Exhibitor 199"
    assert_not_includes text, "noise()"
    assert text.bytesize < html.bytesize / 2,
      "expected a large reduction, got #{text.bytesize} from #{html.bytesize}"
  end
end
