require "test_helper"

class PdfExtractorTest < ActiveSupport::TestCase
  # Committed fixtures rather than PDFs built at runtime, so these tests are
  # deterministic and need no network and no generator gem.
  def fixture(name)
    File.binread(Rails.root.join("test/fixtures/files", name))
  end

  test "extracts the text of every page" do
    text = PdfExtractor.call(fixture("two_page_text.pdf"))

    assert_includes text, "Marriage Divorce Remarriage"
    assert_includes text, "A study paper on family policy."
    assert_includes text, "Second Page Heading"
    assert_includes text, "Budget figures for the following year."
  end

  # The same failure ContentExtractor's BLOCK_SELECTOR exists to prevent: the
  # last word of one page welded to the first word of the next.
  test "pages are separated rather than run together" do
    text = PdfExtractor.call(fixture("two_page_text.pdf"))

    assert_not_includes text, "policy.Second"
    assert_match(/policy\.\nSecond Page Heading/, text)
  end

  test "whitespace is normalized the way page text is" do
    text = PdfExtractor.call(fixture("two_page_text.pdf"))

    assert_not_includes text, "  ",   "runs of spaces should be collapsed"
    assert_not_includes text, "\n\n", "blank-line pileups should be collapsed"
    assert_equal text.strip, text
  end

  # A scan is a genuine outcome, not an error. Raising here would fail a fetch
  # whose bytes were retrieved perfectly well.
  test "an image-only pdf returns an empty string" do
    assert_equal "", PdfExtractor.call(fixture("image_only.pdf"))
  end

  test "an encrypted pdf returns an empty string" do
    assert_equal "", PdfExtractor.call(fixture("encrypted.pdf"))
  end

  test "arbitrary non-pdf bytes return an empty string rather than raising" do
    assert_equal "", PdfExtractor.call("this is not a pdf at all")
    assert_equal "", PdfExtractor.call("\x00\x01\x02\xff".b * 100)
  end

  test "blank input returns an empty string" do
    assert_equal "", PdfExtractor.call(nil)
    assert_equal "", PdfExtractor.call("")
  end
end
