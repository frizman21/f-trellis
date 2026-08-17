require "pdf-reader"
require "stringio"

# Pulls the text out of a fetched PDF, so a document reaches a skill in the same
# shape a page does.
#
# This is the PDF counterpart to ContentExtractor and deliberately has the same
# interface — `call(input) -> String` — so SourceDatum#text can dispatch between
# the two without either caller learning what a PDF is.
#
# The organisations we crawl publish their substance as documents: giving plans,
# budgets, position papers, and — the case that forced this — DARPA BAAs, which
# are never published as web pages at all.
class PdfExtractor
  def self.call(bytes)
    new(bytes).call
  end

  def initialize(bytes)
    @bytes = bytes.to_s
  end

  # Returns "" rather than raising for a PDF that cannot be read — encrypted,
  # malformed, or image-only with no text layer.
  #
  # A scanned document is a genuine outcome, not an error. Raising would send
  # the whole fetch down the failure path *after* the bytes were successfully
  # retrieved, which is both wrong and unhelpful. An empty result flows to a nil
  # content_hash, exactly what an HTML page with no extractable text already
  # produces.
  def call
    return "" if @bytes.empty?

    normalize(pages.join("\n"))
  rescue StandardError => e
    # Deliberately broad: this parses bytes fetched from somebody else's server,
    # and pdf-reader surfaces malformed input as any of a dozen error classes,
    # some of them from Zlib rather than from itself.
    Rails.logger.warn("PdfExtractor: could not read a #{@bytes.bytesize}-byte document: #{e.class}: #{e.message}")
    ""
  end

  private

  # One bad page does not lose the document. A malformed content stream part way
  # through a long solicitation is common enough that dropping the other forty
  # pages over it would be the wrong trade.
  def pages
    PDF::Reader.new(StringIO.new(@bytes.b)).pages.map do |page|
      begin
        page.text.to_s
      rescue StandardError => e
        Rails.logger.warn("PdfExtractor: skipped an unreadable page: #{e.class}: #{e.message}")
        ""
      end
    end
  end

  # The same normalisation ContentExtractor applies, so text from either source
  # reaches a model in the same shape.
  def normalize(text)
    text.gsub(/[ \t\r\f\v]+/, " ")
        .gsub(/ ?\n ?/, "\n")
        .gsub(/\n{2,}/, "\n")
        .strip
  end
end
