require "test_helper"

# An attribute value that is a web address is a link; anything else is text.
# Read off the value, because the ontology has no URL type.
class ValueAsLinkTest < ActionView::TestCase
  include ApplicationHelper

  def link_in(html) = Nokogiri::HTML.fragment(html).at_css("a")

  # The anchor's own text, without the trailing opens-elsewhere icon that
  # external_link_to appends — its SVG source carries indentation, which would
  # otherwise be counted as part of the label.
  def label_of(anchor) = anchor.children.first.text

  # --- what is an address ----------------------------------------------------

  test "https and http values are linked to themselves" do
    [ "https://acme.example/about", "http://acme.example" ].each do |url|
      anchor = link_in(value_as_link(url))

      assert_not_nil anchor, "#{url} should have been linked"
      assert_equal url, anchor["href"]
    end
  end

  # Every other external address in the application opens this way.
  test "a linked value opens elsewhere safely" do
    anchor = link_in(value_as_link("https://acme.example"))

    assert_equal "_blank", anchor["target"]
    assert_includes anchor["rel"], "noopener"
    assert_includes anchor["rel"], "noreferrer"
  end

  # A string that merely looks domain-shaped is more often a part number, a
  # filename or a version than an address somebody meant to be clickable.
  test "anything that is not an http address is left as text" do
    [ "acme.example", "Acme Corporation", "42", "F-1", "v1.2.3",
      "mailto:someone@acme.example", "ftp://files.acme.example",
      "http://", "https:// spaced out" ].each do |value|
      assert_nil link_in(value_as_link(value)), "#{value.inspect} should not have been linked"
    end
  end

  test "a value that is not a parseable uri is text rather than an exception" do
    assert_nothing_raised do
      assert_nil link_in(value_as_link("http://[not a uri"))
    end
  end

  test "a blank value renders as nothing" do
    assert_equal "", value_as_link(nil)
    assert_equal "", value_as_link("")
  end

  test "surrounding whitespace does not stop a value being recognised" do
    assert_equal "https://acme.example", link_in(value_as_link("  https://acme.example  "))["href"]
  end

  # --- truncation ------------------------------------------------------------

  # A shortened href is a broken one: what is shown is cut, what is linked is
  # whole.
  test "a long address is shortened in the text and whole in the href" do
    url = "https://acme.example/#{"a" * 200}"
    anchor = link_in(value_as_link(url, truncate: 40))

    assert_equal url, anchor["href"]
    assert_operator label_of(anchor).length, :<=, 41
    assert_includes label_of(anchor), "..."
  end

  test "long prose is shortened too" do
    assert_equal 40, value_as_link("z" * 200, truncate: 40).length
  end

  # One value to a row on an entity's own page, and no column width to protect.
  test "truncate nil shows the value whole" do
    url = "https://acme.example/#{"a" * 200}"

    assert_equal url, label_of(link_in(value_as_link(url, truncate: nil)))
    assert_equal 200, value_as_link("z" * 200, truncate: nil).length
  end
end
