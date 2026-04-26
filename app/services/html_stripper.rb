require "nokogiri"

class HtmlStripper
  REMOVE_ELEMENTS = %w[script style noscript template head iframe svg].freeze

  PARAGRAPH_ELEMENTS = %w[
    address article aside blockquote details div dl
    fieldset figcaption figure footer form
    h1 h2 h3 h4 h5 h6 header
    main nav ol p pre section table ul
  ].freeze

  LINE_ELEMENTS = %w[br dd dt hr li tr].freeze

  def self.call(html)
    new(html).call
  end

  def initialize(html)
    @html = html.to_s
  end

  def call
    return "" if @html.strip.empty?

    doc = Nokogiri::HTML(@html)

    REMOVE_ELEMENTS.each { |tag| doc.css(tag).each(&:remove) }
    doc.xpath("//comment()").each(&:remove)

    doc.xpath("//text()[not(ancestor::pre)]").each do |node|
      node.content = node.content.gsub(/\s+/, " ")
    end

    PARAGRAPH_ELEMENTS.each do |tag|
      doc.css(tag).each do |node|
        node.add_previous_sibling(Nokogiri::XML::Text.new("\n\n", doc))
        node.add_next_sibling(Nokogiri::XML::Text.new("\n\n", doc))
      end
    end

    LINE_ELEMENTS.each do |tag|
      doc.css(tag).each do |node|
        node.add_next_sibling(Nokogiri::XML::Text.new("\n", doc))
      end
    end

    normalize_whitespace(doc.text)
  end

  private

  def normalize_whitespace(text)
    text.gsub(/[ \t]+/, " ")
        .gsub(/ *\n */, "\n")
        .gsub(/\n{3,}/, "\n\n")
        .strip
  end
end
