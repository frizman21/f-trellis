require "nokogiri"
require "uri"

class LinkExtractor
  # `excluded` is filled in downstream by SourceDatum#extract_links, which
  # applies the SourceExclusion list. Nothing in this class touches it — the
  # extractor stays a parser with no database of its own — so it reads as an
  # empty list on a result that was never filtered.
  # `nofollowed` are links the page itself asked us not to follow. Reported
  # rather than silently dropped, exactly like `excluded` — an empty crawl is
  # much easier to debug when the reasons links went missing are visible.
  Result = Struct.new(:internal, :external, :excluded, :nofollowed, keyword_init: true) do
    def excluded
      self[:excluded] || []
    end

    def nofollowed
      self[:nofollowed] || []
    end
  end

  # `nofollow` is the original; `ugc` and `sponsored` replaced blanket nofollow
  # for user-generated and paid links and mean the same thing here — the site
  # does not vouch for the destination.
  NOFOLLOW_TOKENS = %w[nofollow ugc sponsored].freeze

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
    nofollowed = []

    # A page carrying `nofollow` suppresses its whole link list, which is what
    # the directive means at page level.
    page_follows = RobotsDirectives.from_html(@html).follow?

    doc.css("a[href]").each do |a|
      href = a["href"].to_s.strip
      next if href.empty? || href.start_with?("#")

      url = absolutize(href)
      next unless url
      next unless %w[http https].include?(url.scheme)

      url.fragment = nil

      if !page_follows || nofollow?(a)
        nofollowed << url.to_s
      elsif same_host?(url)
        internal << url.to_s
      else
        external << url.to_s
      end
    end

    # A page vouching for a URL anywhere outweighs a nofollow elsewhere on it.
    followed = internal + external

    Result.new(internal: internal.uniq, external: external.uniq,
               nofollowed: nofollowed.uniq - followed)
  end

  private

  def nofollow?(anchor)
    tokens = anchor["rel"].to_s.downcase.split(/\s+/)

    tokens.any? { |token| NOFOLLOW_TOKENS.include?(token) }
  end

  def absolutize(href)
    URI.join(@base, href)
  rescue URI::InvalidURIError, ArgumentError
    nil
  end

  def same_host?(url)
    url.host&.downcase == @base.host&.downcase
  end
end
