require "nokogiri"
require "uri"

class LinkExtractor
  # `excluded` is filled in downstream by SourceDatum#extract_links, which
  # applies the SourceExclusion list. Nothing in this class touches it — the
  # extractor stays a parser with no database of its own — so it reads as an
  # empty list on a result that was never filtered.
  Result = Struct.new(:internal, :external, :excluded, keyword_init: true) do
    def excluded
      self[:excluded] || []
    end
  end

  def self.call(html, base_url:)
    new(html, base_url).call
  end

  def initialize(html, base_url)
    @html = html.to_s
    @base = URI.parse(base_url.to_s)
  end

  def call
    return Result.new(internal: [], external: []) if @html.strip.empty?

    doc = Nokogiri::HTML(@html)
    internal = []
    external = []

    doc.css("a[href]").each do |a|
      href = a["href"].to_s.strip
      next if href.empty? || href.start_with?("#")

      url = absolutize(href)
      next unless url
      next unless %w[http https].include?(url.scheme)

      url.fragment = nil

      if same_host?(url)
        internal << url.to_s
      else
        external << url.to_s
      end
    end

    Result.new(internal: internal.uniq, external: external.uniq)
  end

  private

  def absolutize(href)
    URI.join(@base, href)
  rescue URI::InvalidURIError, ArgumentError
    nil
  end

  def same_host?(url)
    url.host&.downcase == @base.host&.downcase
  end
end
