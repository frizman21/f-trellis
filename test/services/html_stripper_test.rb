require "test_helper"

class HtmlStripperTest < ActiveSupport::TestCase
  test "returns empty string for blank input" do
    assert_equal "", HtmlStripper.call(nil)
    assert_equal "", HtmlStripper.call("")
    assert_equal "", HtmlStripper.call("   ")
  end

  test "extracts visible text from simple html" do
    assert_equal "Hello world", HtmlStripper.call("<p>Hello world</p>")
  end

  test "removes script tags and their contents" do
    html = "<p>Visible</p><script>alert('hidden')</script>"
    assert_equal "Visible", HtmlStripper.call(html)
  end

  test "removes style tags and their contents" do
    html = "<style>body { color: red; }</style><p>Visible</p>"
    assert_equal "Visible", HtmlStripper.call(html)
  end

  test "removes inline scripts inside body content" do
    html = "<div>before<script>var x = 1;</script>after</div>"
    assert_equal "beforeafter", HtmlStripper.call(html)
  end

  test "removes noscript blocks" do
    html = "<p>Hi</p><noscript>enable js</noscript>"
    assert_equal "Hi", HtmlStripper.call(html)
  end

  test "preserves paragraph breaks between paragraphs" do
    html = "<p>First paragraph.</p><p>Second paragraph.</p>"
    assert_equal "First paragraph.\n\nSecond paragraph.", HtmlStripper.call(html)
  end

  test "preserves headings as their own paragraphs" do
    html = "<h1>Title</h1><p>Body text.</p>"
    assert_equal "Title\n\nBody text.", HtmlStripper.call(html)
  end

  test "preserves list items on separate lines" do
    html = "<ul><li>One</li><li>Two</li><li>Three</li></ul>"
    assert_equal "One\nTwo\nThree", HtmlStripper.call(html)
  end

  test "separates a list from surrounding paragraphs" do
    html = "<p>Before</p><ul><li>One</li><li>Two</li></ul><p>After</p>"
    assert_equal "Before\n\nOne\nTwo\n\nAfter", HtmlStripper.call(html)
  end

  test "preserves line breaks from br tags" do
    html = "<p>Line one<br>Line two</p>"
    assert_equal "Line one\nLine two", HtmlStripper.call(html)
  end

  test "preserves table rows on separate lines" do
    html = "<table><tr><td>a</td><td>b</td></tr><tr><td>c</td><td>d</td></tr></table>"
    assert_equal "ab\ncd", HtmlStripper.call(html)
  end

  test "collapses runs of internal whitespace" do
    html = "<p>Hello    world\n\n\twith   spaces</p>"
    assert_equal "Hello world with spaces", HtmlStripper.call(html)
  end

  test "removes html comments" do
    html = "<p>Visible<!-- hidden comment --></p>"
    assert_equal "Visible", HtmlStripper.call(html)
  end

  test "strips inline formatting but preserves text" do
    html = "<p>This is <strong>bold</strong> and <em>italic</em> text.</p>"
    assert_equal "This is bold and italic text.", HtmlStripper.call(html)
  end

  test "strips full html document leaving structured body text" do
    html = <<~HTML
      <!DOCTYPE html>
      <html>
        <head>
          <title>Page Title</title>
          <style>.x { color: red; }</style>
        </head>
        <body>
          <h1>Heading</h1>
          <p>Paragraph one.</p>
          <p>Paragraph two.</p>
          <script>doStuff();</script>
        </body>
      </html>
    HTML

    assert_equal "Heading\n\nParagraph one.\n\nParagraph two.", HtmlStripper.call(html)
  end
end
