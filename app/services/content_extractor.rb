require "nokogiri"

# Strips markup from a fetched page, leaving the text a skill actually reads.
#
# Raw HTML is overwhelmingly markup: on the exhibitor list in report #30 the
# stored payload is 277,656 bytes (~112,881 tokens) against 20,209 bytes
# (~8,216 tokens) of text — 92.7% of what we were paying to send carried no
# information for the skill. Payloads are still stored as raw HTML because
# LinkExtractor needs the anchors; this runs at read time.
class ContentExtractor
  # Elements whose text is never page content.
  NOISE_SELECTOR = "script, style, noscript, svg, head, link, meta, template".freeze

  # Elements a browser renders on their own line or in their own cell. Without a
  # break after each, adjacent table cells collapse into one run of text — an
  # exhibitor list turns "Acme Corp" and "25016" into "Acme Corp25016". Inline
  # elements are deliberately absent: a browser does not separate those either.
  BLOCK_SELECTOR = %w[
    address article aside blockquote br dd div dl dt fieldset figcaption figure
    footer form h1 h2 h3 h4 h5 h6 header hr li main nav ol p pre section table
    tbody td tfoot th thead tr ul
  ].join(", ").freeze

  def self.call(html)
    new(html).call
  end

  def initialize(html)
    @html = html.to_s
  end

  def call
    return "" if @html.strip.empty?

    doc = Nokogiri::HTML(@html)
    doc.css(NOISE_SELECTOR).remove
    separate_blocks(doc)

    body = doc.at_css("body")
    return "" if body.nil?

    normalize(body.text)
  end

  private

  def separate_blocks(doc)
    doc.css(BLOCK_SELECTOR).each do |node|
      node.add_next_sibling(Nokogiri::XML::Text.new("\n", doc))
    end
  end

  # Collapse the whitespace HTML authors leave behind without joining words that
  # sat in separate elements.
  def normalize(text)
    text.gsub(/[ \t\r\f\v]+/, " ")
        .gsub(/ ?\n ?/, "\n")
        .gsub(/\n{2,}/, "\n")
        .strip
  end
end
